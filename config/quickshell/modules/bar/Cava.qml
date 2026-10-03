import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick
import "../../theme" as Palette
import "../../components/material"

Item {
    id: root

    property bool active: true
    property bool cavaEnabled: true
    property int barCount: 14
    property var levels: []
    property string configPath: String(Qt.resolvedUrl("cava.conf")).replace("file://", "")
    implicitWidth: 110
    implicitHeight: 18

    // True if ANY mpris player is currently playing — not just whichever
    // single "selected" player a parent might bind `active` to. This way
    // cava keeps running as long as something, anything, is making sound.
    readonly property bool anyPlaying: {
        var list = Mpris.players.values;
        for (var i = 0; i < list.length; i++) {
            if (list[i].isPlaying)
                return true;
        }
        return false;
    }

    // Actual "should cava be running" condition combines the external
    // active flag (e.g. widget visibility) with real playback state.
    readonly property bool shouldRun: root.active && root.anyPlaying

    function parseLine(line) {
        var str = line.trim();
        if (!str)
            return;
        var parts = str.split(";");
        var count = Math.min(parts.length, root.barCount);
        var next = [];
        for (var i = 0; i < count; i++) {
            var val = parseInt(parts[i]);
            if (!isNaN(val))
                next.push(Math.max(0, Math.min(1, val / 8)));
            else
                break;
        }
        if (next.length > 0)
            root.levels = next;
    }

    onShouldRunChanged: {
        cavaEnabled = shouldRun;
        if (!shouldRun)
            levels = [];
    }

    Process {
        id: cava
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

    Row {
        id: barRow
        anchors.centerIn: parent
        spacing: 3

        Repeater {
            model: root.barCount

            Item {
                readonly property real barWidth: Math.max(2, (root.width - barRow.spacing * (root.barCount - 1)) / root.barCount)
                readonly property real level: (root.levels && root.levels.length > index) ? root.levels[index] : 0.05
                readonly property real barHeight: Math.max(3, level * root.height)

                width: barWidth
                height: root.height

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.barWidth
                    height: parent.barHeight
                    radius: width / 2
                    color: Palette.Theme.accent
                    opacity: 0.45 + parent.level * 0.55

                    Behavior on height {
                        SpatialMotion {
                            fast: true
                        }
                    }
                }
            }
        }
    }
}
