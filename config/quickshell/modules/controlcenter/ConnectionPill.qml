import QtQuick
import QtQuick.Layouts
import "../../components/material"
import "../../theme" as Palette

// A wide connectivity toggle (Wi-Fi, Bluetooth), Caelestia-style: an icon
// disc that fills with the accent when on, a title and status, and an arrow
// that opens the device list. Click the pill to toggle it.
Rectangle {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false
    signal clicked
    signal openList

    implicitHeight: 56
    radius: height / 2
    color: active ? Palette.Theme.accentTonal : Palette.Theme.surfaceContainerLow
    scale: mouse.pressed ? 0.97 : 1

    Behavior on color {
        ColorMotion {}
    }
    Behavior on scale {
        SpatialMotion {
            fast: true
            bouncy: true
        }
    }

    StateLayer {
        radius: parent.radius
        hovered: mouse.containsMouse
        pressed: mouse.pressed
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: event => event.button === Qt.RightButton ? root.openList() : root.clicked()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 6
        spacing: 10

        Rectangle {
            Layout.preferredWidth: 40
            Layout.preferredHeight: 40
            radius: width / 2
            color: root.active ? Palette.Theme.accent : Palette.Theme.surfaceContainerHigh

            Behavior on color {
                ColorMotion {}
            }

            Text {
                anchors.centerIn: parent
                text: root.icon
                color: root.active ? Palette.Theme.accentText : Palette.Theme.textSecondary
                font.family: Palette.Theme.fontIcons
                font.pixelSize: Palette.Theme.iconSize
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
                Layout.fillWidth: true
                text: root.title
                color: Palette.Theme.textPrimary
                font.family: Palette.Theme.fontSans
                font.pixelSize: Palette.Theme.fontSizeBody
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: root.subtitle
                color: root.active ? Palette.Theme.accent : Palette.Theme.textMuted
                font.family: Palette.Theme.fontSans
                font.pixelSize: Palette.Theme.fontSizeXs
                elide: Text.ElideRight
            }
        }

        IconButton {
            icon: "chevron_right"
            implicitWidth: 30
            implicitHeight: 30
            iconSize: Palette.Theme.iconSize
            onClicked: root.openList()
        }
    }
}
