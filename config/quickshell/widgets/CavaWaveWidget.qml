import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Effects
import "../theme" as Palette
import "../components/material"

// Desktop audio visualizer: cava's spectrum drawn as layered rolling hills
// (WaveVisualizer), instead of discrete bars. Sits on the same translucent
// card as the clock and weather widgets. cava only runs while some MPRIS
// player is playing; when playback stops the hills ease back down flat.
Item {
    id: root

    property var widgetsService: null
    readonly property string widgetId: "cava"
    property real defaultX: 0
    property real defaultY: 0

    // Must match `bars` in cava-wave.conf.
    readonly property int pointCount: 20
    property string configPath: String(Qt.resolvedUrl("cava-wave.conf")).replace("file://", "")
    property bool cavaEnabled: true

    // Latest frame from cava; WaveVisualizer eases between frames.
    property var levels: []

    implicitWidth: 320
    implicitHeight: 96
    width: implicitWidth
    height: implicitHeight

    x: widgetsService && widgetsService.hasPosition(widgetId) ? widgetsService.positionX(widgetId) : defaultX
    y: widgetsService && widgetsService.hasPosition(widgetId) ? widgetsService.positionY(widgetId) : defaultY

    readonly property bool anyPlaying: {
        var list = Mpris.players.values;
        for (var i = 0; i < list.length; i++) {
            if (list[i].isPlaying)
                return true;
        }
        return false;
    }

    readonly property bool shouldRun: root.visible && root.anyPlaying

    onShouldRunChanged: {
        cavaEnabled = shouldRun;
        if (!shouldRun)
            levels = [];
    }

    function parseLine(line) {
        var parts = line.trim().split(";");
        var next = [];
        for (var i = 0; i < Math.min(parts.length, root.pointCount); i++) {
            var val = parseInt(parts[i]);
            if (isNaN(val))
                break;
            // sqrt lifts quiet passages so the wave doesn't sit nearly flat.
            next.push(Math.sqrt(Math.max(0, Math.min(1, val / 100))));
        }
        if (next.length > 0)
            root.levels = next;
    }

    Process {
        command: ["cava", "-p", root.configPath]
        running: root.shouldRun && root.cavaEnabled
        onExited: {
            if (root.shouldRun) {
                root.cavaEnabled = false;
                retryCava.restart();
            }
        }
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root.parseLine(data)
        }
    }

    Timer {
        id: retryCava
        interval: 2000
        onTriggered: if (root.shouldRun)
            root.cavaEnabled = true
    }

    Rectangle {
        anchors.fill: parent
        radius: Palette.Theme.radiusLarge
        // Same language as the rest of the shell: tonal surface, no outline.
        color: Qt.alpha(Palette.Theme.surfaceContainer, 0.85)

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.45)
            shadowBlur: 0.8
            shadowVerticalOffset: 4
        }
    }

    WaveVisualizer {
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        anchors.topMargin: 14
        anchors.bottomMargin: 14
        levels: root.levels
    }

    // Drag-to-reposition. Position is persisted on release rather than on
    // every move, to avoid hammering the state file.
    MouseArea {
        anchors.fill: parent
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        drag.target: root
        drag.minimumX: 0
        drag.minimumY: 0
        drag.maximumX: root.parent ? root.parent.width - root.width : 0
        drag.maximumY: root.parent ? root.parent.height - root.height : 0

        onPressed: root.z = 1000
        onReleased: {
            root.z = 0;
            if (root.widgetsService)
                root.widgetsService.setPosition(root.widgetId, root.x, root.y);
        }
    }
}
