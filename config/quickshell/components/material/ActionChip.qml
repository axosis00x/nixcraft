import QtQuick
import "../../theme" as Palette

// Pill chip: outlined when idle, accent-filled when active. Morphs from a
// rounded rectangle to a full pill as it activates.
Rectangle {
    id: root

    required property string label
    property bool active: false
    property real chipHeight: 28
    property int fontPixelSize: Palette.Theme.fontSizeXs
    property int horizontalPadding: 18
    signal clicked

    implicitHeight: root.chipHeight
    implicitWidth: chipText.implicitWidth + root.horizontalPadding
    radius: root.active ? height / 2 : Palette.Theme.radiusSmall
    color: root.active ? Palette.Theme.accent : "transparent"
    border.color: Palette.Theme.outlineSoft
    border.width: root.active ? 0 : 1

    Behavior on radius {
        SpatialMotion {}
    }
    Behavior on color {
        ColorMotion {}
    }

    scale: actionMouse.pressed ? 0.94 : 1
    Behavior on scale {
        SpatialMotion {
            fast: true
            bouncy: true
        }
    }

    StateLayer {
        radius: parent.radius
        tone: root.active ? Palette.Theme.accentText : Palette.Theme.textPrimary
        hovered: actionMouse.containsMouse
        pressed: actionMouse.pressed
    }

    Text {
        id: chipText
        anchors.centerIn: parent
        text: root.label
        color: root.active ? Palette.Theme.accentText : Palette.Theme.textSecondary
        font.family: Palette.Theme.fontSans
        font.pixelSize: root.fontPixelSize
        font.weight: root.active ? Font.DemiBold : Font.Medium

        Behavior on color {
            ColorMotion {}
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
