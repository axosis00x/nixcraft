import QtQuick
import QtQuick.Layouts
import "../../theme" as Palette

Rectangle {
    id: root

    required property string label
    property bool active: false
    property real chipHeight: 28
    property int fontPixelSize: 11
    property int horizontalPadding: 18
    signal clicked

    implicitHeight: root.chipHeight
    implicitWidth: chipText.implicitWidth + root.horizontalPadding
    radius: height / 2

    // Material 3 Expressive Tonal Container
    color: root.active
        ? Palette.Theme.accent
        : (actionMouse.containsMouse ? Palette.Theme.surfaceContainerHighest : Palette.Theme.surfaceContainerHigh)

    border.color: root.active
        ? "transparent"
        : (actionMouse.containsMouse ? Palette.Theme.accent : Palette.Theme.outlineVariant)
    border.width: root.active ? 0 : 1

    Behavior on color {
        ColorAnimation { duration: 140 }
    }

    Behavior on border.color {
        ColorAnimation { duration: 140 }
    }

    // M3 Expressive responsive spring scaling
    scale: actionMouse.pressed ? 0.93 : (actionMouse.containsMouse ? 1.04 : 1.0)
    Behavior on scale {
        NumberAnimation {
            duration: 150
            easing.type: Easing.OutBack
            easing.overshoot: 1.6
        }
    }

    // State layer overlay (Hover/Press glow)
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: root.active ? "#ffffff" : Palette.Theme.accent
        opacity: actionMouse.pressed ? 0.18 : (actionMouse.containsMouse ? 0.08 : 0)

        Behavior on opacity {
            NumberAnimation { duration: 120 }
        }
    }

    Text {
        id: chipText
        anchors.centerIn: parent
        text: root.label
        color: root.active
            ? Palette.Theme.accentText
            : (actionMouse.containsMouse ? Palette.Theme.textPrimary : Palette.Theme.textSecondary)
        font.family: Palette.Theme.fontSans
        font.pixelSize: root.fontPixelSize
        font.weight: root.active ? Font.DemiBold : Font.Medium
        font.letterSpacing: 0.2
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        Behavior on color {
            ColorAnimation { duration: 120 }
        }
    }

    MouseArea {
        id: actionMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
