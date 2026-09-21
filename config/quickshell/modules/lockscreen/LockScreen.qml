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
        command: ["sh", "-c", "theme=$(sed -n 's/.*dofile(\"\\(.*\\)\").*/\\1/p' \"$HOME/.config/hypr/theme.lua\" 2>/dev/null | head -n1 | xargs -r dirname | xargs -r basename); find \"$HOME/Pictures/wallpapers/$theme\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \\) 2>/dev/null | shuf -n 1"]
        stdout: StdioCollector {
            onStreamFinished: {
                var path = text.trim();
                if (path !== "")
                    root.wallpaperPath = path;
            }
        }
    }

    Component.onCompleted: refreshWallpaper()
}
