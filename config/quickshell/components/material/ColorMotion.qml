import QtQuick
import "../../theme" as Palette

// Motion atom for color changes; pairs with EffectMotion.
ColorAnimation {
    property bool fast: true

    duration: fast ? Palette.Theme.effectFast : Palette.Theme.effectDefault
    easing.type: Easing.OutCubic
}
