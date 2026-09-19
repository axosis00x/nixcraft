import QtQuick
import "../../theme" as Palette

Item {
    id: root

    property bool checked: false
    property color accentColor: Palette.Theme.accent
    signal toggled(bool value)

    implicitWidth: 38
    implicitHeight: 22

    // M3 Expressive tactile spring scaling
    scale: switchMouse.pressed ? 0.90 : (switchMouse.containsMouse ? 1.05 : 1.0)
    Behavior on scale {
        NumberAnimation {
            duration: 140
            easing.type: Easing.OutBack
            easing.overshoot: 1.6
        }
    }

    // Track
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? root.accentColor : Palette.Theme.surfaceContainerHighest
        border.color: root.checked ? "transparent" : (switchMouse.containsMouse ? Palette.Theme.accent : Palette.Theme.outlineVariant)
        border.width: root.checked ? 0 : 1

        Behavior on color {
            ColorAnimation { duration: 150 }
        }
        Behavior on border.color {
            ColorAnimation { duration: 150 }
        }
    }

    // Thumb (handle)
    Rectangle {
        id: thumb
        readonly property real thumbBaseSize: parent.height - 6
        width: switchMouse.pressed ? thumbBaseSize + 4 : thumbBaseSize
        height: thumbBaseSize
        radius: height / 2
        y: 3
        x: root.checked ? parent.width - width - 3 : 3
        color: root.checked ? Palette.Theme.accentText : (switchMouse.containsMouse ? Palette.Theme.textPrimary : Palette.Theme.textSecondary)

        Behavior on x {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutBack
                easing.overshoot: 1.4
            }
        }
        Behavior on width {
            NumberAnimation { duration: 100 }
        }
        Behavior on color {
            ColorAnimation { duration: 120 }
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
