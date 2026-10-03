import QtQuick
import QtQuick.Layouts
import "../../theme" as Palette
import "../../components/material"

Item {
    id: root

    property string iconSource: ""
    property string iconGlyph: ""
    property real value: 0
    property string label: "0%"

    implicitWidth: 208
    implicitHeight: 40

    RowLayout {
        anchors.fill: parent
        spacing: 12

        Item {
            Layout.preferredWidth: 20
            Layout.preferredHeight: 20
            Layout.alignment: Qt.AlignVCenter

            Image {
                anchors.fill: parent
                source: root.iconSource
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
                sourceSize.width: 20
                sourceSize.height: 20
            }

            Text {
                anchors.centerIn: parent
                visible: root.iconSource === "" && root.iconGlyph !== ""
                text: root.iconGlyph
                color: Palette.Theme.textPrimary
                font.family: Palette.Theme.fontIcons
                font.pixelSize: Palette.Theme.iconSize
            }
        }

        Slider {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            interactive: false
            trackHeight: 8
            value: root.value
        }

        Text {
            text: root.label
            color: Palette.Theme.textPrimary
            font.family: Palette.Theme.fontMono
            font.pixelSize: Palette.Theme.fontSizeSmall
            horizontalAlignment: Text.AlignRight
            Layout.preferredWidth: 34
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
