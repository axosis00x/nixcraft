import QtQuick
import "../../components/material"
import "../../theme" as Palette

// Sidebar entry. The selection pill itself is drawn by the sidebar (it
// glides between entries); an entry only adds its hover/press state layer
// and a springy squeeze when pressed.
Item {
    id: root

    property string icon: ""
    property string label: ""
    property bool selected: false
    signal clicked

    implicitHeight: 40

    scale: mouse.pressed ? 0.96 : 1
    Behavior on scale {
        SpatialMotion {
            fast: true
            bouncy: true
        }
    }

    StateLayer {
        radius: height / 2
        hovered: mouse.containsMouse && !root.selected
        pressed: mouse.pressed
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: Palette.Theme.spacingMedium
        spacing: Palette.Theme.spacingMedium

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            color: root.selected ? Palette.Theme.accent : Palette.Theme.textMuted
            font.family: Palette.Theme.fontIcons
            font.pixelSize: Palette.Theme.iconSize

            Behavior on color {
                ColorMotion {}
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            color: root.selected ? Palette.Theme.textPrimary : Palette.Theme.textSecondary
            font.family: Palette.Theme.fontSans
            font.pixelSize: Palette.Theme.fontSizeBody
            font.weight: root.selected ? Font.DemiBold : Font.Normal
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
