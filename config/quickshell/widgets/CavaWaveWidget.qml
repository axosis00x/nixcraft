import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Effects
import "../theme" as Palette

// Desktop audio visualizer: cava's spectrum drawn as one smooth wave rising
// from a baseline, instead of discrete bars. Sits on the same translucent
// card as the clock and weather widgets. cava only runs while some MPRIS
// player is playing; when playback stops the wave eases back down to a flat
// line.
Item {
    id: root

    property var widgetsService: null
    readonly property string widgetId: "cava"
    property real defaultX: 0
    property real defaultY: 0

    // Must match `bars` in cava-wave.conf.
    readonly property int pointCount: 20
    property string configPath: String(Qt.resolvedUrl("cava-wave.conf")).replace("file://", "")
    property bool cavaEnabled: true

    // Latest values from cava, and the eased values actually drawn.
    property var target: []
    property var shown: []

    implicitWidth: 320
    implicitHeight: 96
    width: implicitWidth
    height: implicitHeight

    x: widgetsService && widgetsService.hasPosition(widgetId) ? widgetsService.positionX(widgetId) : defaultX
    y: widgetsService && widgetsService.hasPosition(widgetId) ? widgetsService.positionY(widgetId) : defaultY

    readonly property bool anyPlaying: {
        var list = Mpris.players.values;
        for (var i = 0; i < list.length; i++) {
            if (list[i].isPlaying)
                return true;
        }
        return false;
    }

    readonly property bool shouldRun: root.visible && root.anyPlaying

    onShouldRunChanged: {
        cavaEnabled = shouldRun;
        if (!shouldRun)
            target = [];
        else
            animator.start();
    }

    function parseLine(line) {
        var parts = line.trim().split(";");
        var next = [];
        for (var i = 0; i < Math.min(parts.length, root.pointCount); i++) {
            var val = parseInt(parts[i]);
            if (isNaN(val))
                break;
            // sqrt lifts quiet passages so the wave doesn't sit nearly flat.
            next.push(Math.sqrt(Math.max(0, Math.min(1, val / 100))));
        }
        if (next.length > 0) {
            // Soften neighbouring bands into each other so crests come out
            // as broad rounded swells rather than isolated spikes.
            var soft = [];
            for (var j = 0; j < next.length; j++) {
                var l = next[Math.max(0, j - 1)];
                var r = next[Math.min(next.length - 1, j + 1)];
                soft.push((l + 2 * next[j] + r) / 4);
            }
            root.target = soft;
            animator.start();
        }
    }

    Process {
        command: ["cava", "-p", root.configPath]
        running: root.shouldRun && root.cavaEnabled
        onExited: {
            if (root.shouldRun) {
                root.cavaEnabled = false;
                retryCava.restart();
            }
        }
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root.parseLine(data)
        }
    }

    Timer {
        id: retryCava
        interval: 2000
        onTriggered: if (root.shouldRun)
            root.cavaEnabled = true
    }

    // Eases the drawn wave toward cava's latest frame at display rate, so
    // the 30 fps input still moves fluidly. Stops itself once everything
    // has settled (e.g. flat after playback ends).
    Timer {
        id: animator
        interval: 16
        repeat: true
        onTriggered: {
            var next = [];
            var moving = false;
            for (var i = 0; i < root.pointCount; i++) {
                var from = root.shown.length > i ? root.shown[i] : 0;
                var to = root.target.length > i ? root.target[i] : 0;
                var v = from + (to - from) * 0.3;
                if (Math.abs(to - v) > 0.002)
                    moving = true;
                else
                    v = to;
                next.push(v);
            }
            root.shown = next;
            wave.requestPaint();
            if (!moving && !root.shouldRun)
                stop();
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Palette.Theme.radiusExtraLarge
        color: Qt.alpha(Palette.Theme.surfaceContainer, 0.8)
        border.width: 1
        border.color: Palette.Theme.outlineSoft

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.45)
            shadowBlur: 0.8
            shadowVerticalOffset: 4
        }
    }

    Canvas {
        id: wave
        anchors.fill: parent
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        anchors.topMargin: 14
        anchors.bottomMargin: 14

        readonly property color accent: Palette.Theme.accent
        onAccentChanged: requestPaint()
        onWidthChanged: requestPaint()

        // Traces the wave's crest as a Catmull-Rom spline through every
        // sample (converted to cubic Béziers), which keeps peaks round
        // instead of pinched, rising from a baseline along the bottom edge.
        function trace(ctx, pts) {
            var base = height - 1;
            var amp = height - 4;
            var step = width / (pts.length - 1);
            var n = pts.length;
            function px(k) {
                return Math.max(0, Math.min(n - 1, k)) * step;
            }
            function py(k) {
                return base - Math.max(0.6, pts[Math.max(0, Math.min(n - 1, k))] * amp);
            }
            ctx.lineTo(0, base);
            ctx.lineTo(px(0), py(0));
            for (var k = 0; k < n - 1; k++) {
                var c1x = px(k) + (px(k + 1) - px(k - 1)) / 6;
                var c1y = py(k) + (py(k + 1) - py(k - 1)) / 6;
                var c2x = px(k + 1) - (px(k + 2) - px(k)) / 6;
                var c2y = py(k + 1) - (py(k + 2) - py(k)) / 6;
                ctx.bezierCurveTo(c1x, c1y, c2x, c2y, px(k + 1), py(k + 1));
            }
            ctx.lineTo(width, base);
        }

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();

            // Pad with zeros so the wave tapers into the baseline at both ends.
            var pts = [0].concat(root.shown);
            while (pts.length < root.pointCount + 1)
                pts.push(0);
            pts.push(0);

            var fill = ctx.createLinearGradient(0, 0, 0, height);
            fill.addColorStop(0, Qt.alpha(accent, 0.45));
            fill.addColorStop(1, Qt.alpha(accent, 0.04));

            ctx.beginPath();
            ctx.moveTo(0, height - 1);
            trace(ctx, pts);
            ctx.closePath();
            ctx.fillStyle = fill;
            ctx.fill();

            ctx.lineWidth = 2;
            ctx.lineJoin = "round";
            ctx.strokeStyle = accent;
            ctx.beginPath();
            ctx.moveTo(0, height - 1);
            trace(ctx, pts);
            ctx.stroke();
        }
    }

    // Drag-to-reposition. Position is persisted on release rather than on
    // every move, to avoid hammering the state file.
    MouseArea {
        anchors.fill: parent
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        drag.target: root
        drag.minimumX: 0
        drag.minimumY: 0
        drag.maximumX: root.parent ? root.parent.width - root.width : 0
        drag.maximumY: root.parent ? root.parent.height - root.height : 0

        onPressed: root.z = 1000
        onReleased: {
            root.z = 0;
            if (root.widgetsService)
                root.widgetsService.setPosition(root.widgetId, root.x, root.y);
        }
    }
}
