import QtQuick
import "../../theme" as Palette

// Sidebar entry. The selected one gets a full pill in a tonal color and the
// others relax back to a softer rounded rectangle.
Item {
    id: root

    property string icon: ""
    property string label: ""
    property bool selected: false
    property color tint: Palette.Theme.accent
    signal clicked

    implicitHeight: 50

    Rectangle {
        anchors.fill: parent
        radius: root.selected ? height / 2 : 16
        color: root.selected ? Qt.alpha(root.tint, 0.24) : (mouse.containsMouse ? Palette.Theme.surfaceContainerHigh : "transparent")
        scale: mouse.pressed ? 0.97 : 1

        Behavior on radius {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: 140
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 140
                easing.type: Easing.OutBack
                easing.overshoot: 2
            }
        }
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 16
        spacing: 14

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            color: root.selected ? root.tint : Palette.Theme.textSecondary
            font.family: Palette.Theme.fontIcons
            font.pixelSize: 22

            Behavior on color {
                ColorAnimation {
                    duration: 140
                }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            color: root.selected ? Palette.Theme.textPrimary : Palette.Theme.textSecondary
            font.family: Palette.Theme.fontSans
            font.pixelSize: 14
            font.weight: root.selected ? Font.DemiBold : Font.Medium
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
