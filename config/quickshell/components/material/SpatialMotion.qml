import QtQuick
import "../../theme" as Palette

// Motion atom for position, size, shape and scale: a short spring that
// overshoots and settles (Material 3 Expressive "spatial" motion).
//   Behavior on radius { SpatialMotion {} }
//   Behavior on scale { SpatialMotion { fast: true; bouncy: true } }
NumberAnimation {
    property bool fast: false
    property bool bouncy: false

    duration: fast ? Palette.Theme.motionFast : Palette.Theme.motionDefault
    easing.type: Easing.OutBack
    easing.overshoot: bouncy ? Palette.Theme.springBouncy : Palette.Theme.springOvershoot
}
