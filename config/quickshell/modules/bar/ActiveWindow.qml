import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Widgets
import Quickshell
import QtQuick
import QtQuick.Layouts
import "../../theme" as Palette
import "../../components/material"

Item {
    id: root

    implicitWidth: mediaPlaying ? 180 : contentRow.implicitWidth
    implicitHeight: 26

    property var player: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null
    property bool mediaPlaying: player !== null && player.playbackState === MprisPlaybackState.Playing

    property string appClass: ""
    property string appTitle: "Desktop"

    property string _nextClass: ""
    property string _nextTitle: "Desktop"

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name !== "activewindow")
                return;
            var idx = event.data.indexOf(",");
            if (idx <= 0) {
                root._nextClass = "";
                root._nextTitle = "Desktop";
            } else {
                root._nextClass = event.data.substring(0, idx);
                root._nextTitle = event.data.substring(idx + 1);
            }

            if (root._nextClass === root.appClass && root._nextTitle === root.appTitle)
                return;
            switchAnim.restart();
        }
    }

    SequentialAnimation {
        id: switchAnim

        ParallelAnimation {
            NumberAnimation {
                target: contentRow
                property: "opacity"
                to: 0
                duration: 110
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: contentRow
                property: "y"
                to: 5
                duration: 110
                easing.type: Easing.InCubic
            }
        }

        ScriptAction {
            script: {
                root.appClass = root._nextClass;
                root.appTitle = root._nextTitle;
            }
        }

        PropertyAction {
            target: contentRow
            property: "y"
            value: -5
        }

        ParallelAnimation {
            NumberAnimation {
                target: contentRow
                property: "opacity"
                to: 1
                duration: 180
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: contentRow
                property: "y"
                to: 0
                duration: 180
                easing.type: Easing.OutCubic
            }
        }
    }

    Cava {
        id: cava
        anchors.centerIn: parent
        active: root.mediaPlaying && visible
        visible: root.mediaPlaying
        opacity: root.mediaPlaying ? 1 : 0

        Behavior on opacity {
            EffectMotion {}
        }
    }

    RowLayout {
        id: contentRow
        spacing: 7
        anchors.verticalCenter: parent.verticalCenter
        visible: !root.mediaPlaying
        opacity: root.mediaPlaying ? 0 : 1

        Behavior on opacity {
            EffectMotion {}
        }

        IconImage {
            implicitSize: 14
            source: root.appClass !== "" ? Quickshell.iconPath(root.appClass, true) : ""
            visible: source !== ""
            smooth: true
            mipmap: true
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            text: root.appTitle
            color: Palette.Theme.textTitle
            font.family: Palette.Theme.fontMono
            font.pixelSize: Palette.Theme.fontSizeSmall
            elide: Text.ElideRight
            Layout.maximumWidth: 240
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
