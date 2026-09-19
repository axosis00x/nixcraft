import QtQuick
import QtQuick.Layouts
import "../../components/material"
import "../../theme" as Palette

Item {
    id: root

    property string iconSource: ""
    property string iconGlyph: ""
    property string title: ""
    property string subtitle: ""
    property bool active: false
    // Label for the row's action button (e.g. "Connect" / "Disconnect").
    // Empty hides the button entirely.
    property string actionLabel: ""
    signal actionClicked

    implicitWidth: 1
    implicitHeight: 46

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: rowMouse.containsMouse ? Palette.Theme.surfaceContainerHigh : "transparent"
        border.width: 0

        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 10

        Rectangle {
            implicitWidth: 32
            implicitHeight: 32
            radius: 16
            color: root.active ? Palette.Theme.surfaceContainerHighest : Palette.Theme.surfaceContainerHigh
            Layout.alignment: Qt.AlignVCenter

            Image {
                anchors.centerIn: parent
                width: 16
                height: 16
                source: root.iconSource
                visible: root.iconSource !== ""
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
            }

            Text {
                anchors.centerIn: parent
                visible: root.iconSource === "" && root.iconGlyph !== ""
                text: root.iconGlyph
                color: root.active ? Palette.Theme.accent : Palette.Theme.textSecondary
                font.family: Palette.Theme.fontIcons
                font.pixelSize: 18
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Layout.alignment: Qt.AlignVCenter

            Text {
                text: root.title
                color: Palette.Theme.textPrimary
                font.family: Palette.Theme.fontSans
                font.pixelSize: 13
                font.weight: Font.Medium
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Text {
                text: root.subtitle
                color: Palette.Theme.textMuted
                font.family: Palette.Theme.fontSans
                font.pixelSize: 11
                elide: Text.ElideRight
                Layout.fillWidth: true
                visible: text !== ""
            }
        }

        ActionChip {
            visible: root.actionLabel !== ""
            label: root.actionLabel
            active: root.active
            Layout.alignment: Qt.AlignVCenter
            onClicked: root.actionClicked()
        }
    }

    MouseArea {
        id: rowMouse
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }
}
