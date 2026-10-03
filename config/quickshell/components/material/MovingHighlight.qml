import QtQuick
import "../../theme" as Palette

// One highlight that glides between list rows instead of each row lighting
// up on its own: it springs to whichever item `target` points at, resizes to
// fit it, and fades in place when `target` goes null (pointer left the list).
// Appearing from hidden snaps straight to the target rather than sliding in
// from wherever it last was.
//
// As a ListView/GridView highlight:
//   highlightFollowsCurrentItem: false
//   highlight: MovingHighlight { target: view.currentItem }
// For a plain Column/Repeater, place it as a sibling below the rows and
// point `target` at the hovered/selected delegate.
//
// Defaults to a filled state; for an outline ring drawn over opaque cards,
// set color: "transparent", border.width/color, and z above the delegates.
Rectangle {
    id: root

    property Item target: null
    property real insetX: 0
    property real insetY: 0

    property real targetX: 0
    property real targetY: 0
    property real targetWidth: 0
    property real targetHeight: 0
    property bool instant: true

    radius: Palette.Theme.radiusMedium
    color: Palette.Theme.surfaceContainerHigh

    x: targetX
    y: targetY
    width: targetWidth
    height: targetHeight
    opacity: target ? 1 : 0
    visible: opacity > 0.01

    Behavior on targetX {
        enabled: !root.instant
        SpatialMotion {}
    }
    Behavior on targetY {
        enabled: !root.instant
        SpatialMotion {}
    }
    Behavior on targetWidth {
        enabled: !root.instant
        SpatialMotion {}
    }
    Behavior on targetHeight {
        enabled: !root.instant
        SpatialMotion {}
    }
    Behavior on opacity {
        EffectMotion {}
    }

    function sync() {
        if (!target || !parent)
            return;
        var p = target.mapToItem(parent, 0, 0);
        targetX = p.x + insetX;
        targetY = p.y + insetY;
        targetWidth = Math.max(0, target.width - insetX * 2);
        targetHeight = Math.max(0, target.height - insetY * 2);
    }

    onTargetChanged: {
        // Snap when (re)appearing, glide when moving between rows.
        instant = opacity < 0.05;
        sync();
        instant = false;
    }

    Connections {
        target: root.target
        ignoreUnknownSignals: true
        function onXChanged() {
            root.sync();
        }
        function onYChanged() {
            root.sync();
        }
        function onWidthChanged() {
            root.sync();
        }
        function onHeightChanged() {
            root.sync();
        }
    }
}
