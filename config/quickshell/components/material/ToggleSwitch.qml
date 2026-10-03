import QtQuick
import "../../theme" as Palette

// Material 3 switch: a small outlined thumb when off that grows (and gains
// a check) when on, springing across the track; pressing swells it.
Item {
    id: root

    property bool checked: false
    property color accentColor: Palette.Theme.accent
    signal toggled(bool value)

    implicitWidth: 44
    implicitHeight: 26

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? root.accentColor : Palette.Theme.surfaceContainerHighest
        border.width: root.checked ? 0 : 2
        border.color: switchMouse.containsMouse ? Palette.Theme.textSecondary : Palette.Theme.textMuted

        Behavior on color {
            ColorMotion {}
        }
    }

    Rectangle {
        id: thumb

        // Center and diameter animate independently, so the thumb can
        // swell on press while it springs across the track.
        property real centerX: root.checked ? root.width - root.height / 2 : root.height / 2

        width: switchMouse.pressed ? root.height - 4 : (root.checked ? root.height - 8 : root.height - 14)
        height: width
        radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        x: centerX - width / 2
        color: root.checked ? Palette.Theme.accentText : (switchMouse.containsMouse ? Palette.Theme.textSecondary : Palette.Theme.textMuted)

        Behavior on centerX {
            SpatialMotion {}
        }
        Behavior on width {
            SpatialMotion {
                fast: true
            }
        }
        Behavior on color {
            ColorMotion {}
        }

        Text {
            anchors.centerIn: parent
            text: "check"
            color: root.accentColor
            font.family: Palette.Theme.fontIcons
            font.pixelSize: parent.width * 0.75
            opacity: root.checked ? 1 : 0

            Behavior on opacity {
                EffectMotion {}
            }
        }
    }

    MouseArea {
        id: switchMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
