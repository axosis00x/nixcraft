import QtQuick
import QtQuick.Layouts
import "../../theme" as Palette

Item {
    id: root

    property string title: "Lock"
    property string iconSource: ""
    property string iconGlyph: ""
    property bool enabled: false

    implicitWidth: lockRow.implicitWidth + 24
    implicitHeight: 40

    RowLayout {
        id: lockRow
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Item {
            implicitWidth: 24
            implicitHeight: 24
            Layout.alignment: Qt.AlignVCenter

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Palette.Theme.surfaceContainer
            }

            Image {
                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: 0
                width: 16
                height: 16
                source: root.iconSource
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
                opacity: root.enabled ? 1 : 0.35
            }

            Text {
                anchors.centerIn: parent
                visible: root.iconSource === "" && root.iconGlyph !== ""
                text: root.iconGlyph
                color: Palette.Theme.textPrimary
                opacity: root.enabled ? 1 : 0.35
                font.family: Palette.Theme.fontIcons
                font.pixelSize: Palette.Theme.iconSizeSmall
            }
        }

            Text {
                text: root.title
                color: Palette.Theme.textPrimary
                font.family: Palette.Theme.fontMono
                font.pixelSize: Palette.Theme.fontSizeSmall
                font.weight: Font.DemiBold
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                text: root.enabled ? "ON" : "OFF"
                color: root.enabled ? Palette.Theme.accent : Palette.Theme.textMuted
                font.family: Palette.Theme.fontMono
                font.pixelSize: Palette.Theme.fontSizeXs
                font.weight: Font.Black
                Layout.alignment: Qt.AlignVCenter
            }
        }
}
