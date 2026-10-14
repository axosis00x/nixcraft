import QtQuick
import "../../theme" as Palette

// A calm placeholder: a muted icon over a short message.
Column {
    id: root

    property string icon: ""
    property string text: ""

    spacing: 6

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.icon
        color: Palette.Theme.textMuted
        font.family: Palette.Theme.fontIcons
        font.weight: Palette.Theme.iconWeight
        font.pixelSize: Palette.Theme.iconSizeLarge * 1.4
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text: root.text
        color: Palette.Theme.textMuted
        font.family: Palette.Theme.fontSans
        font.pixelSize: Palette.Theme.fontSizeSmall
    }
}
