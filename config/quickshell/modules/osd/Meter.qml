import QtQuick
import QtQuick.Layouts
import "../../theme" as Palette
import "../../components/material"

Item {
    id: root

    property string iconSource: ""
    property string iconGlyph: ""
    property real value: 0
    property color accent: Palette.Theme.accent
    property color trackColor: Palette.Theme.surfaceContainerHighest
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
                color: Palette.Theme.osdText
                font.family: Palette.Theme.fontIcons
                font.weight: Palette.Theme.iconWeight
                font.pixelSize: Palette.Theme.iconSize
            }
        }

        Slider {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            interactive: false
            trackHeight: 8
            accent: root.accent
            trackColor: root.trackColor
            value: root.value
        }

        Text {
            text: root.label
            color: Palette.Theme.osdText
            font.family: Palette.Theme.fontMono
            font.pixelSize: Palette.Theme.fontSizeSmall
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignRight
            Layout.preferredWidth: 34
            Layout.alignment: Qt.AlignVCenter
        }
    }
}
