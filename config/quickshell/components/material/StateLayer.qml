import QtQuick
import "../../theme" as Palette

// Hover/press feedback: a translucent wash of the content color over
// whatever surface it fills. Set `radius` to match the parent's shape.
Rectangle {
    property bool hovered: false
    property bool pressed: false
    property color tone: Palette.Theme.textPrimary

    anchors.fill: parent
    color: tone
    opacity: pressed ? Palette.Theme.statePressed : (hovered ? Palette.Theme.stateHover : 0)

    Behavior on opacity {
        EffectMotion {}
    }
}
