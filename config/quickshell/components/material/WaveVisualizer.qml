import QtQuick
import "../../theme" as Palette

// An audio spectrum drawn as rolling hills: one solid ridge traced as a
// spline so every crest stays round. Feed `levels` (0..1 per band) at cava's frame
// rate; the hills ease between frames at display rate and settle flat once
// `levels` empties.
Canvas {
    id: root

    property var levels: []
    property color tint: Palette.Theme.accent

    // Eased heights actually drawn.
    property var shown: []

    onLevelsChanged: animator.start()
    onTintChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    // Binomial blur: folds each band into its neighbours so a single loud
    // band reads as a swell rather than a spike, while separate crests stay
    // separate.
    function soften(arr) {
        var n = arr.length;
        var out = [];
        for (var i = 0; i < n; i++) {
            var at = k => arr[Math.max(0, Math.min(n - 1, i + k))];
            out.push((at(-1) + 2 * at(0) + at(1)) / 4);
        }
        return out;
    }

    Timer {
        id: animator
        interval: 16
        repeat: true
        onTriggered: {
            var n = Math.max(root.levels.length, root.shown.length);
            var target = root.soften(root.levels);
            var next = [];
            var moving = false;
            for (var i = 0; i < n; i++) {
                var a = root.shown.length > i ? root.shown[i] : 0;
                var b = target.length > i ? target[i] : 0;
                var v = a + (b - a) * 0.3;
                if (Math.abs(b - v) > 0.002)
                    moving = true;
                else
                    v = b;
                next.push(v);
            }
            root.shown = next;
            root.requestPaint();
            if (!moving)
                stop();
        }
    }

    // Closed hill silhouette: a Catmull-Rom spline through every sample
    // (as cubic Béziers), tapering into the baseline at both ends.
    function hills(ctx, values) {
        var pts = [0].concat(values).concat([0]);
        var n = pts.length;
        var amp = height - 1;
        var step = width / (n - 1);
        var px = k => Math.max(0, Math.min(n - 1, k)) * step;
        var py = k => height - Math.max(1, pts[Math.max(0, Math.min(n - 1, k))] * amp);
        ctx.beginPath();
        ctx.moveTo(0, height);
        ctx.lineTo(px(0), py(0));
        for (var k = 0; k < n - 1; k++) {
            ctx.bezierCurveTo(px(k) + (px(k + 1) - px(k - 1)) / 6, py(k) + (py(k + 1) - py(k - 1)) / 6, px(k + 1) - (px(k + 2) - px(k)) / 6, py(k + 1) - (py(k + 2) - py(k)) / 6, px(k + 1), py(k + 1));
        }
        ctx.lineTo(width, height);
        ctx.closePath();
    }

    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();
        if (shown.length === 0)
            return;

        var fill = ctx.createLinearGradient(0, 0, 0, height);
        fill.addColorStop(0, Qt.alpha(tint, 0.95));
        fill.addColorStop(1, Qt.alpha(tint, 0.55));
        hills(ctx, shown);
        ctx.fillStyle = fill;
        ctx.fill();
    }
}
