import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../material"
import "../../theme" as Palette

// Live activity: the top notch widens into a pill while something runs:
// a recording (click to stop), a timer (`qs ipc call timer start <s>`,
// `... timer stop`) or a download (click to open the folder).
Item {
    id: root

    property var bar: null
    // Height of the notch the pill grows out of, so it stays as slim.
    property real baseHeight: 34

    // ── sources ─────────────────────────────────────────────────────
    readonly property bool recording: bar ? bar.isRecording : false
    property double recordStart: 0
    onRecordingChanged: recordStart = recording ? Date.now() : 0

    property double timerEnd: 0
    property double timerTotal: 0
    readonly property bool timing: timerEnd > 0

    property var downloads: [] // [{ name, size }]

    readonly property var activities: {
        var list = [];
        if (recording)
            list.push("record");
        if (timing)
            list.push("timer");
        if (downloads.length > 0)
            list.push("download");
        return list;
    }
    readonly property string kind: activities.length > 0 ? activities[0] : ""
    // CenterOverlay shows this on the stage while true.
    readonly property bool wanted: kind !== "" && !(bar && bar.centerActivitySuppressed)

    // A 1 s clock for elapsed/remaining times; runs only while needed.
    property double now: Date.now()
    Timer {
        interval: 1000
        repeat: true
        running: root.recording || root.timing
        triggeredOnStart: true
        onTriggered: {
            root.now = Date.now();
            if (root.timing && root.now >= root.timerEnd)
                root.finishTimer();
        }
    }

    function clock(ms) {
        var s = Math.max(0, Math.round(ms / 1000));
        var h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), sec = s % 60;
        var mm = (m < 10 && h > 0 ? "0" : "") + m, ss = (sec < 10 ? "0" : "") + sec;
        return (h > 0 ? h + ":" : "") + mm + ":" + ss;
    }

    function size(bytes) {
        return bytes >= 1073741824 ? (bytes / 1073741824).toFixed(1) + " GB" : (bytes / 1048576).toFixed(1) + " MB";
    }

    function startTimer(seconds) {
        if (seconds <= 0)
            return;
        timerTotal = seconds * 1000;
        timerEnd = Date.now() + timerTotal;
        now = Date.now();
    }

    function finishTimer() {
        timerEnd = 0;
        notifier.exec(["notify-send", "-a", "Timer", "-u", "critical", "Timer finished", root.clock(root.timerTotal) + " is up"]);
    }

    IpcHandler {
        target: "timer"
        function start(seconds: int): void {
            root.startTimer(seconds);
        }
        function stop(): void {
            root.timerEnd = 0;
        }
    }

    Process {
        id: notifier
    }

    // Partial downloads. One cheap `find` every few seconds.
    Process {
        id: downloadScan
        command: ["sh", "-c", "d=$(xdg-user-dir DOWNLOAD 2>/dev/null); [ -d \"$d\" ] || d=\"$HOME/Downloads\"; find \"$d\" -maxdepth 1 -type f \\( -name '*.part' -o -name '*.crdownload' -o -name '*.download' -o -name '*.partial' \\) -printf '%s\\t%f\\n' 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                var list = [];
                text.split("\n").forEach(line => {
                    var tab = line.indexOf("\t");
                    if (tab > 0)
                        list.push({
                            size: Number(line.slice(0, tab)),
                            name: line.slice(tab + 1).replace(/\.(part|crdownload|download|partial)$/, "")
                        });
                });
                // Avoid re-binding the pill when nothing changed.
                if (JSON.stringify(list) !== JSON.stringify(root.downloads))
                    root.downloads = list;
            }
        }
    }
    Timer {
        interval: 3000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: downloadScan.running = true
    }

    Process {
        id: action
    }

    // ── pill ────────────────────────────────────────────────────────
    readonly property string icon: kind === "record" ? "radio_button_checked" : kind === "timer" ? "timer" : kind === "download" ? "download" : ""
    readonly property color tone: kind === "record" ? Palette.Theme.errorColor : kind === "timer" ? Palette.Theme.yellow : Palette.Theme.blue
    readonly property string label: kind === "record" ? "Recording" : kind === "timer" ? "Timer" : kind === "download" ? downloads[0].name : ""
    readonly property string value: kind === "record" ? clock(now - recordStart) : kind === "timer" ? clock(timerEnd - now) : kind === "download" ? size(downloads[0].size) : ""
    // 0–1 for the timer, -1 (indeterminate) for downloads, none otherwise.
    readonly property real progress: kind === "timer" ? Math.min(1, 1 - (timerEnd - now) / timerTotal) : kind === "download" ? -1 : 0
    readonly property real contentWidth: iconText.implicitWidth + labelText.implicitWidth + valueText.implicitWidth + 16 + 24 + (activities.length > 1 ? more.implicitWidth + 18 : 0)

    implicitWidth: Math.min(260, Math.max(160, contentWidth))
    implicitHeight: Math.max(baseHeight, 34)
    enabled: wanted
    // Hidden once faded out: a transparent item still catches hover, which
    // blocked the power and tool menus beneath it on the top stage.
    visible: opacity > 0.01

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 8

        Text {
            id: iconText
            text: root.icon
            color: root.tone
            font.family: Palette.Theme.fontIcons
            font.weight: Palette.Theme.iconWeight
            font.pixelSize: Palette.Theme.iconSizeSmall

            // The recording dot breathes.
            SequentialAnimation on opacity {
                running: root.kind === "record"
                loops: Animation.Infinite
                onRunningChanged: if (!running)
                    parent.opacity = 1
                NumberAnimation {
                    to: 0.35
                    duration: 700
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: 1
                    duration: 700
                    easing.type: Easing.InOutSine
                }
            }
        }

        Text {
            id: labelText
            Layout.fillWidth: true
            text: root.label
            color: Palette.Theme.textPrimary
            font.family: Palette.Theme.fontSans
            font.pixelSize: Palette.Theme.fontSizeSmall
            font.weight: Font.DemiBold
            elide: Text.ElideMiddle
        }

        Text {
            id: valueText
            text: root.value
            color: root.tone
            font.family: Palette.Theme.fontMono
            font.pixelSize: Palette.Theme.fontSizeSmall
            font.features: {
                "tnum": 1
            }
        }

        Rectangle {
            visible: root.activities.length > 1
            implicitWidth: more.implicitWidth + 10
            implicitHeight: 18
            radius: height / 2
            color: Palette.Theme.accentTonal

            Text {
                id: more
                anchors.centerIn: parent
                text: "+" + (root.activities.length - 1)
                color: Palette.Theme.accent
                font.family: Palette.Theme.fontSans
                font.pixelSize: Palette.Theme.fontSizeXs
                font.weight: Font.DemiBold
            }
        }
    }

    // Progress along the bottom edge: filling for the timer, a sliding
    // segment while a download's size is unknown.
    Item {
        visible: root.progress !== 0
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 16
        anchors.rightMargin: 16
        anchors.bottomMargin: 3
        height: 2
        clip: true

        Rectangle {
            anchors.fill: parent
            radius: 1
            color: Palette.Theme.outlineSoft
        }

        Rectangle {
            visible: root.progress > 0
            height: parent.height
            radius: 1
            color: root.tone
            width: parent.width * Math.max(0, root.progress)

            Behavior on width {
                EffectMotion {
                    fast: false
                }
            }
        }

        Rectangle {
            id: slider
            visible: root.progress < 0
            height: parent.height
            width: parent.width * 0.3
            radius: 1
            color: root.tone

            NumberAnimation on x {
                running: slider.visible && root.wanted
                from: -slider.width
                to: slider.parent.width
                duration: 1400
                loops: Animation.Infinite
                easing.type: Easing.InOutSine
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: root.kind === "record" || root.kind === "download" ? Qt.PointingHandCursor : Qt.ArrowCursor
        property bool wheelLocked: false

        Timer {
            id: wheelUnlock
            interval: 260
            onTriggered: parent.wheelLocked = false
        }

        onWheel: wheel => {
            wheel.accepted = true;
            if (wheelLocked || !root.bar || typeof root.bar.scrollCenterModule !== "function")
                return;
            root.bar.scrollCenterModule(wheel.angleDelta.y);
            wheelLocked = true;
            wheelUnlock.restart();
        }

        onClicked: {
            if (root.kind === "record")
                action.exec(["bash", "-lc", "~/.config/quickshell/scripts/record.sh"]);
            else if (root.kind === "download")
                action.exec(["sh", "-c", "d=$(xdg-user-dir DOWNLOAD 2>/dev/null); [ -d \"$d\" ] || d=\"$HOME/Downloads\"; xdg-open \"$d\""]);
        }
    }
}
