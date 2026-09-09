import QtQuick
import "../../theme" as Palette

Rectangle {
    id: root

    property color tint: Palette.Theme.surfaceTint
    property real tintOpacity: Palette.Theme.surfaceTintOpacity
    property color outlineColor: Palette.Theme.outlineVariant
    property real outlineWidth: 0

    radius: Palette.Theme.radiusLarge
    color: Palette.Theme.surfaceContainer
    border.color: root.outlineColor
    border.width: root.outlineWidth
    // Without this, content inset less than the corner radius (a common
    // case near a rounded corner) can visually poke past the rounded
    // silhouette instead of being cut off by it.
    clip: true

    Rectangle {
        anchors.fill: parent
        anchors.margins: root.outlineWidth
        radius: parent.radius
        color: root.tint
        opacity: root.tintOpacity
        visible: root.tintOpacity > 0
    }
}
