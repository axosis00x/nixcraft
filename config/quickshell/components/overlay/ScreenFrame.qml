import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Shapes
import "../material"
import "../../theme" as Palette

// The left bar's screen frame: a band in the bar's color along every edge,
// with rounded inner corners, so the bar and the frame read as one surface
// the desktop sits inside (Caelestia-style). Island mode floats the bar off
// the edge, and the frame fades out. Its size is in theme/Theme.qml.
//
// It sits just above the wallpaper, under windows, bars and panels, so they
// draw over it, and takes no input. The edges without a bar reserve its
// width, so windows keep their usual gap from it.
Variants {
    id: root

    required property var barLayout

    readonly property real border: Palette.Theme.screenFrameBorder
    readonly property real radius: Palette.Theme.screenFrameRadius
    // Only with the left bar in notch mode: the top bar and island mode
    // have no frame, and it fades out when switching to them.
    // In notch mode, for every bar position; island mode has no frame.
    readonly property bool shown: barLayout ? (barLayout.loaded && !barLayout.island) : false
    readonly property bool vertical: barLayout ? barLayout.vertical : false

    model: Quickshell.screens

    Scope {
        id: perScreen

        required property var modelData

        PanelWindow {
            id: frame

            screen: perScreen.modelData
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            // Drawn under everything across the whole screen; the strips
            // below do the reserving.
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            mask: Region {}

            // Above windows (Top), so a floating window dragged to the edge
            // goes under the frame instead of covering it; fullscreen apps
            // still cover it, as Hyprland draws them above this layer.
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "quickshell-screen-frame"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            visible: shape.opacity > 0

            Shape {
                id: shape
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                opacity: root.shown ? 1 : 0

                Behavior on opacity {
                    EffectMotion {}
                }

                // The whole screen minus a rounded rectangle inset by the
                // border: even-odd fill leaves the band and its corners.
                ShapePath {
                    fillColor: Palette.Theme.bg
                    strokeColor: "transparent"
                    strokeWidth: 0
                    fillRule: ShapePath.OddEvenFill

                    Behavior on fillColor {
                        ColorMotion {}
                    }

                    PathRectangle {
                        x: 0
                        y: 0
                        width: frame.width
                        height: frame.height
                    }
                    PathRectangle {
                        x: root.border
                        y: root.border
                        width: frame.width - 2 * root.border
                        height: frame.height - 2 * root.border
                        radius: root.radius
                    }
                }
            }
        }

        // One invisible strip per edge without the bar, reserving the band's
        // width so windows stay clear of it.
        Variants {
            model: root.shown ? (root.vertical ? ["top", "bottom", "right"] : ["left", "bottom", "right"]) : []

            PanelWindow {
                required property string modelData

                screen: perScreen.modelData
                anchors {
                    top: modelData !== "bottom"
                    bottom: modelData !== "top"
                    left: modelData !== "right"
                    right: modelData !== "left"
                }
                implicitHeight: root.border
                implicitWidth: root.border
                exclusiveZone: root.border
                color: "transparent"
                mask: Region {}

                // Hyprland hands out reserved space layer by layer, bottom
                // first: on the top layer these come after the bar, so the
                // bar keeps its whole edge and they take only what's left.
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.namespace: "quickshell-screen-frame-reserve"
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            }
        }
    }
}
