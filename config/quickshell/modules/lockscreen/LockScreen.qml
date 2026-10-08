import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pam
import QtQuick

Item {
    id: root

    property string passwordBuffer: ""
    // What's been typed so far, shared by every monitor's lock surface so
    // the dots show up everywhere no matter which one holds keyboard focus.
    property string typed: ""
    property bool authBusy: false
    property bool authFailed: false
    property int failedAttempts: 0
    property string wallpaperPath: ""
    // Subject cut out of the wallpaper (transparent PNG, same size) for the
    // depth effect; empty until one exists. Generated once per wallpaper and
    // cached, so only the first lock with a new wallpaper waits for it.
    property string depthPath: ""

    readonly property string lockscreenDir: Quickshell.env("HOME") + "/Pictures/wallpapers/lockscreen"
    readonly property string depthScript: Quickshell.env("HOME") + "/.config/quickshell/scripts/depth-cutout.sh"

    // Depth cutouts only for images in the lock screen folder.
    onWallpaperPathChanged: {
        depthPath = "";
        if (wallpaperPath.indexOf(lockscreenDir + "/") === 0)
            depthRead.exec([depthScript, wallpaperPath]);
    }

    readonly property bool isLocked: sessionLock.locked

    signal unlocked
    signal engaged

    function refreshWallpaper() {
        wallpaperRead.running = true;
    }

    function lock() {
        if (sessionLock.locked)
            return;
        root.passwordBuffer = "";
        root.typed = "";
        root.authFailed = false;
        root.authBusy = false;
        root.failedAttempts = 0;
        refreshWallpaper();
        if (!depthWarm.running)
            depthWarm.running = true;
        sessionLock.locked = true;
        root.engaged();
        // Best-effort: keeps logind's own LockedHint/Lock signal in sync so
        // other session-aware tools see a consistent state.
        lockHint.exec(["loginctl", "lock-session"]);
    }

    function submitTyped() {
        var pw = root.typed;
        root.typed = "";
        root.submit(pw);
    }

    function submit(password) {
        if (password === "" || root.authBusy)
            return;
        root.passwordBuffer = password;
        root.authFailed = false;
        root.authBusy = true;
        if (!pam.start()) {
            root.authBusy = false;
            root.authFailed = true;
            root.passwordBuffer = "";
        }
    }

    PamContext {
        id: pam
        config: "login"

        onResponseRequiredChanged: {
            if (responseRequired)
                respond(root.passwordBuffer);
        }

        onCompleted: result => {
            root.authBusy = false;
            root.passwordBuffer = "";
            if (result === PamResult.Success) {
                sessionLock.locked = false;
            } else {
                root.authFailed = true;
                root.failedAttempts += 1;
            }
        }

        onError: error => {
            root.authBusy = false;
            root.authFailed = true;
            root.passwordBuffer = "";
        }
    }

    WlSessionLock {
        id: sessionLock

        onLockedChanged: {
            if (!locked)
                root.unlocked();
        }

        surface: Component {
            LockSurface {
                lockScreen: root
            }
        }
    }

    IpcHandler {
        target: "lockscreen"
        function lock(): void {
            root.lock();
        }
    }

    Process {
        id: lockHint
    }

    Process {
        id: wallpaperRead
        // Next image from the lock screen folder, without repeats until
        // every image has been shown. Nothing when the folder is empty — the
        // lock screen then shows a plain background.
        command: [Quickshell.env("HOME") + "/.config/quickshell/scripts/lockscreen-wallpaper.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.wallpaperPath = text.trim();
            }
        }
    }

    Process {
        id: depthRead
        stdout: StdioCollector {
            onStreamFinished: {
                var path = text.trim();
                // Ignore a result for a wallpaper that's since been replaced.
                if (path !== "" && !depthRead.running)
                    root.depthPath = path;
            }
        }
    }

    // Make any missing cutouts for the lock screen folder in the background,
    // so new images are ready by the time they're picked.
    Process {
        id: depthWarm
        command: ["nice", "-n", "19", root.depthScript, "--all", root.lockscreenDir]
    }

    Component.onCompleted: {
        refreshWallpaper();
        depthWarm.running = true;
    }
}
