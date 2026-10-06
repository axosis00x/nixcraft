import QtQuick
import QtQuick.Shapes
import "../../theme" as Palette

// The bar's center element, shaped like a notch cut out of the top screen edge:
// a flat-topped slab with rounded bottom corners, flanked by two concave wings
// that curve back up to the screen edge.
//
// The fill is drawn directly as a Shape/ShapePath with CurveRenderer —
// the same GPU hardware path pipeline as Rectangle.radius. No MultiEffect
// masking is involved, so there is no mask threshold, no resampling, and no
// aliasing artifacts at the curve edges.
Item {
    id: root

    // Width of the flat slab only; the wings add `wingSize` on either side.
    property real slabWidth: 200
    property real slabHeight: 44
    property real slabRadius: 16
    property real wingSize: 14
    // Extra inset at the bottom of contentHolder so child content
    // never paints over the rounded bottom corners.
    property real contentBottomPadding: 0
    // Set false when content is guaranteed not to overflow (e.g. static bar
    // notch) to skip the stencil-buffer pass.
    property bool clipContent: true
    // Mirrors the whole notch top-to-bottom so it hangs off the *bottom*
    // screen edge instead of the top (flat edge + wings at the bottom,
    // rounded corners at the top). Used for the vertical-bar overlay stage,
    // which has no top bar to seed from.
    property bool bottomAligned: false

    // Island mode: instead of hanging from the screen edge with concave
    // wings, the slab floats `islandGap` away from the edge as a fully
    // rounded island (a "dynamic island"). Size morphing is unchanged; the
    // switch itself crossfades the two silhouettes while the content slides
    // off the edge.
    property bool island: false
    property real islandGap: 6
    property real islandRadius: slabRadius
    property real islandness: island ? 1 : 0
    Behavior on islandness {
        SpatialMotion {}
    }
    readonly property real islandOffset: islandGap * islandness

    property color color: Palette.Theme.surfaceContainer
    property color tint: Palette.Theme.surfaceTint
    property real tintOpacity: Palette.Theme.surfaceTintOpacity
    property color outlineColor: Palette.Theme.outlineVariant
    property real outlineWidth: 1

    default property alias content: contentHolder.data

    implicitWidth: slabWidth + wingSize * 2
    // The island's gap from the edge is part of the item, on the edge side.
    implicitHeight: slabHeight + islandOffset

    readonly property real wing: Math.max(0, Math.min(wingSize, height))
    readonly property real effectiveRadius: Math.max(0, Math.min(slabRadius, height - wing, slabWidth / 2))

    // Draw the notch fill directly as a Shape — no MultiEffect mask pipeline.
    // CurveRenderer uses the GPU hardware path renderer for smooth curves
    // identical in quality to Rectangle.radius.
    Shape {
        anchors.fill: parent
        opacity: 1 - root.islandness
        visible: opacity > 0.01
        antialiasing: true
        // CurveRenderer (Qt 6.6+) gives best sub-pixel quality; falls back
        // to GeometryRenderer on older builds.
        preferredRendererType: Shape.CurveRenderer
        // The path below is drawn left-right symmetric, so rotating the
        // whole thing 180° is equivalent to a pure vertical flip (mirroring
        // horizontally would be a no-op on a symmetric shape) — cheaper and
        // less error-prone than re-deriving a mirrored path.
        rotation: root.bottomAligned ? 180 : 0

        ShapePath {
            // Pre-blend tint into the base color so a single path covers both.
            fillColor: Qt.tint(root.color, Qt.rgba(root.tint.r, root.tint.g, root.tint.b, root.tintOpacity))
            strokeColor: "transparent"
            strokeWidth: 0

            startX: 0
            startY: 0

            // Top edge
            PathLine { x: 2 * root.wing + root.slabWidth; y: 0 }

            // Right concave wing arc (270°→180° CCW, 90° sweep)
            PathArc {
                x: root.wing + root.slabWidth; y: root.wing
                radiusX: root.wing; radiusY: root.wing
                direction: PathArc.Counterclockwise
            }

            // Right slab side
            PathLine { x: root.wing + root.slabWidth; y: root.slabHeight - root.effectiveRadius }

            // Bottom-right corner (0°→90° CW)
            PathArc {
                x: root.wing + root.slabWidth - root.effectiveRadius; y: root.slabHeight
                radiusX: root.effectiveRadius; radiusY: root.effectiveRadius
                direction: PathArc.Clockwise
            }

            // Bottom edge
            PathLine { x: root.wing + root.effectiveRadius; y: root.slabHeight }

            // Bottom-left corner (90°→180° CW)
            PathArc {
                x: root.wing; y: root.slabHeight - root.effectiveRadius
                radiusX: root.effectiveRadius; radiusY: root.effectiveRadius
                direction: PathArc.Clockwise
            }

            // Left slab side
            PathLine { x: root.wing; y: root.wing }

            // Left concave wing arc (0°→270° CCW, 90° sweep)
            PathArc {
                x: 0; y: 0
                radiusX: root.wing; radiusY: root.wing
                direction: PathArc.Counterclockwise
            }
        }
    }

    // The island silhouette: the slab, rounded on all four corners, offset
    // from the screen edge by the gap.
    Rectangle {
        x: root.wing
        y: root.bottomAligned ? 0 : root.islandOffset
        width: root.slabWidth
        height: root.slabHeight
        radius: Math.min(root.islandRadius, root.slabWidth / 2, root.slabHeight / 2)
        color: Qt.tint(root.color, Qt.rgba(root.tint.r, root.tint.g, root.tint.b, root.tintOpacity))
        opacity: root.islandness
        visible: opacity > 0.01
    }

    Item {
        id: contentHolder
        x: root.wing
        // When bottom-aligned the rounded corners move to the top, so the
        // padding that used to protect the bottom corners now needs to
        // protect the top ones instead.
        y: root.bottomAligned ? root.contentBottomPadding : root.islandOffset
        width: root.slabWidth
        height: Math.max(0, root.slabHeight - root.contentBottomPadding)
        clip: root.clipContent
    }
}
