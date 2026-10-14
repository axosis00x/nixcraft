import Quickshell.Widgets
import QtQuick
import "../../theme" as Palette

// Album art with rounded corners, or a music note while there is none.
// `source` should be the media panel's cached local file (artSource), never
// the raw MPRIS URL.
ClippingRectangle {
    id: root

    property string source: ""

    radius: Palette.Theme.radiusMedium
    color: Palette.Theme.surfaceContainerHigh

    Text {
        anchors.centerIn: parent
        visible: art.status !== Image.Ready
        text: "music_note"
        color: Palette.Theme.textMuted
        font.family: Palette.Theme.fontIcons
        font.weight: Palette.Theme.iconWeight
        font.pixelSize: Math.round(root.height * 0.4)
    }

    Image {
        id: art
        anchors.fill: parent
        source: root.source
        sourceSize: Qt.size(root.width * 2, root.height * 2)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        mipmap: true
    }
}
