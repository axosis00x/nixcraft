import QtQuick
import QtQuick.Layouts
import "../../components/material"
import "../../theme" as Palette

// A connection card. Clicking it toggles its radio; the arrow (or a right
// click) opens the network or device list. On, it fills with tonal accent and
// its corners round out further.
Rectangle {
    id: root

    property string icon: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false
    signal clicked
    signal openList

    implicitHeight: 64
    radius: active ? Palette.Theme.radiusLarge : Palette.Theme.radiusMedium
    color: active ? Palette.Theme.accentTonal : Palette.Theme.surfaceContainerLow
    scale: mouse.pressed ? 0.985 : 1

    Behavior on radius {
        SpatialMotion {}
    }
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
        tone: root.active ? Palette.Theme.accent : Palette.Theme.textPrimary
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
        // Even sides: the icon disc and the chevron glyph sit 12 px in.
        anchors.leftMargin: 12
        anchors.rightMargin: 7
        spacing: 10

        Rectangle {
            Layout.preferredWidth: 36
            Layout.preferredHeight: 36
            radius: Math.min(width / 2, Palette.Theme.radiusMedium)
            color: root.active ? Palette.Theme.accent : Palette.Theme.surfaceContainerHigh

            Behavior on radius {
                SpatialMotion {
                    fast: true
                }
            }
            Behavior on color {
                ColorMotion {}
            }

            Text {
                anchors.centerIn: parent
                text: root.icon
                color: root.active ? Palette.Theme.bg : Palette.Theme.textSecondary
                font.family: Palette.Theme.fontIcons
                font.weight: Palette.Theme.iconWeight
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
            implicitWidth: 28
            implicitHeight: 28
            iconSize: Palette.Theme.iconSize
            onClicked: root.openList()
        }
    }
}
