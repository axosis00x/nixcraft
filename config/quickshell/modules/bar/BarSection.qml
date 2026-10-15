import QtQuick
import "../../components/material"
import "../../theme" as Palette

// Capsule that groups bar content, in both the horizontal and vertical bar.
// Same background as the notch and the central panels (the theme bg), so
// the whole bar reads as one surface.
Surface {
    color: Palette.Theme.bg
    tintOpacity: 0
    implicitHeight: 30
    radius: Palette.Theme.radiusSmall
    outlineWidth: 0
    clip: false
}
