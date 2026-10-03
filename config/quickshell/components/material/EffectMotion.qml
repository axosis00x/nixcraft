import QtQuick
import "../../theme" as Palette

// Motion atom for opacity and other non-spatial numbers: eases out with no
// overshoot (Material 3 Expressive "effects" motion).
NumberAnimation {
    property bool fast: true

    duration: fast ? Palette.Theme.effectFast : Palette.Theme.effectDefault
    easing.type: Easing.OutCubic
}
