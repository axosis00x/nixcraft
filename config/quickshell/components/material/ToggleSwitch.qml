import QtQuick
import "../../theme" as Palette

Item {
    id: root

    property bool checked: false
    property color accentColor: Palette.Theme.accent
    signal toggled(bool value)

    implicitWidth: 34
    implicitHeight: 19

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? root.accentColor : Palette.Theme.surfaceContainerHighest

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }
    }

    Rectangle {
        width: parent.height - 4
        height: parent.height - 4
        radius: height / 2
        y: 2
        x: root.checked ? parent.width - width - 2 : 2
        color: "#ffffff"

        Behavior on x {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutCubic
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled(!root.checked)
    }
}
