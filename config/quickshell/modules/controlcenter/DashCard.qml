import QtQuick
import "../../components/material"
import "../../theme" as Palette

// One rounded tonal card of the dashboard grid, the same surface the
// control center's groups use.
Surface {
    // Concentric with the panel: its 20px corners less the 10px gap, rounded up.
    radius: Palette.Theme.radiusSmall
    color: Palette.Theme.surfaceContainerLow
    tintOpacity: 0.025
    clip: true
}
