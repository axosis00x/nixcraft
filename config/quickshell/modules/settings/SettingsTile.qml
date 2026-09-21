import QtQuick
import "../../theme" as Palette

// Large quick-settings toggle. Filled with the tint (and rounder) when on.
Item {
    id: root

    property string icon: ""
    property string title: ""
    property string stateText: ""
    property color tint: Palette.Theme.accent
    property bool checked: false
    signal toggled(bool value)

    implicitHeight: 96

    Rectangle {
        anchors.fill: parent
        radius: mouse.pressed ? 18 : (root.checked ? 32 : 22)
        color: root.checked ? root.tint : (mouse.containsMouse ? Palette.Theme.surfaceContainerHighest : Palette.Theme.surfaceContainerHigh)

        Behavior on radius {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutBack
                easing.overshoot: 1.6
            }
        }
        Behavior on color {
            ColorAnimation {
                duration: 160
            }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 14
        width: 38
        height: 38
        radius: 19
        color: root.checked ? Qt.alpha(Palette.Theme.accentText, 0.16) : Qt.alpha(root.tint, 0.2)

        Text {
            anchors.centerIn: parent
            text: root.icon
            color: root.checked ? Palette.Theme.accentText : root.tint
            font.family: Palette.Theme.fontIcons
            font.pixelSize: 21
        }
    }

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 14
        anchors.bottomMargin: 12
        spacing: 0

        Text {
            width: parent.width
            text: root.title
            color: root.checked ? Palette.Theme.accentText : Palette.Theme.textPrimary
            font.family: Palette.Theme.fontSans
            font.pixelSize: 13
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: root.stateText
            color: root.checked ? Qt.alpha(Palette.Theme.accentText, 0.75) : Palette.Theme.textMuted
            font.family: Palette.Theme.fontSans
            font.pixelSize: 11
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
