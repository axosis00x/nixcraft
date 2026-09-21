import QtQuick
import "../../theme" as Palette

// Material 3 Expressive-style slider: a thick pill track filled from the left
// with the icon inside.
Item {
    id: root

    property real value: 0
    property string icon: ""
    property color accent: Palette.Theme.accent
    signal moved(real value)

    property real dragValue: 0
    readonly property real shown: mouse.pressed ? dragValue : value

    implicitHeight: 26

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: Palette.Theme.surfaceContainerHighest
        clip: true

        Rectangle {
            id: fill
            height: parent.height
            width: Math.max(height, parent.width * root.shown)
            radius: height / 2
            color: root.accent

            Behavior on width {
                enabled: !mouse.pressed
                NumberAnimation {
                    duration: 160
                    easing.type: Easing.OutCubic
                }
            }

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 9
                anchors.verticalCenter: parent.verticalCenter
                text: root.icon
                color: Palette.Theme.accentText
                font.family: Palette.Theme.fontIcons
                font.pixelSize: 16
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        function apply(x) {
            root.dragValue = Math.max(0, Math.min(1, x / width));
            root.moved(root.dragValue);
        }

        onPressed: event => apply(event.x)
        onPositionChanged: event => {
            if (pressed)
                apply(event.x);
        }
    }
}
