import Quickshell
import QtQuick
import "../../components/material"
import "../../theme" as Palette

// Nothing-style glyph matrix playing a pattern. A toy; it controls nothing.
//   hover: glow and control bar   click: ring + next pattern   drag: paint
//   scroll: change pattern        right click: pause
Item {
    id: root

    // Animate only while on screen.
    property bool running: visible

    // A fixed number of rows; as many columns as the width fits (odd, so
    // the patterns have a centre column).
    readonly property int rows: 13
    readonly property real pitch: (height - 20) / rows
    readonly property int cols: {
        var n = Math.max(rows, Math.floor((width - 20) / pitch));
        return n % 2 ? n : n - 1;
    }
    readonly property real dotSize: Math.max(2, Math.round(pitch * 0.62))

    readonly property var modeNames: ["Ripple", "Radar", "Rain", "Heart", "Clock", "Name", "Sand timer"]
    // Each pattern glows in its own hue from the theme.
    readonly property color hue: [Palette.Theme.accent, Palette.Theme.aqua, Palette.Theme.blue, Palette.Theme.purple, Palette.Theme.yellow, Palette.Theme.green, Palette.Theme.orange][mode]

    // `tick` always runs (so touches answer even while paused); `phase`
    // drives the pattern and stops while paused.
    property int tick: 0
    property int phase: 0
    property int mode: 0
    property int modeTicks: 0
    property bool paused: false
    property bool autoCycle: true
    property var now: new Date()

    // Touch state, mutated in place; every dot re-reads it each tick.
    property var bursts: []     // [{ x, y, at }]
    property var painted: ({})  // cell index -> tick it was painted
    property real hoverCol: -10
    property real hoverRow: -10

    function setMode(m) {
        mode = (m + modeNames.length) % modeNames.length;
        modeTicks = 0;
        nameFlash.restart();
    }

    function burst(col, row) {
        bursts.push({
            x: col,
            y: row,
            at: tick
        });
        if (bursts.length > 4)
            bursts.shift();
    }

    implicitWidth: 120
    implicitHeight: 120

    Timer {
        interval: 70
        repeat: true
        running: root.running
        onTriggered: {
            root.tick++;
            if (!root.paused)
                root.phase++;
            if (root.tick % 14 === 0)
                root.now = new Date();
            if (root.autoCycle && !root.paused && ++root.modeTicks >= 110)
                root.setMode(root.mode + 1);
        }
    }

    // A stable pseudo-random number per column, for the rain.
    function hash(n) {
        var s = Math.sin(n * 127.1 + 311.7) * 43758.5453;
        return s - Math.floor(s);
    }

    // 3×5 digits for the clock pattern.
    readonly property var digits: [["111", "101", "101", "101", "111"], ["010", "110", "010", "010", "111"], ["111", "001", "111", "100", "111"], ["111", "001", "111", "001", "111"], ["101", "101", "111", "001", "001"], ["111", "100", "111", "001", "111"], ["111", "100", "111", "101", "111"], ["111", "001", "010", "010", "010"], ["111", "101", "111", "101", "111"], ["111", "101", "111", "001", "111"]]

    // A small lowercase pixel font for the name pattern: 3 dots wide, a
    // 3-dot x-height with short ascenders and a 1-dot descender (6 rows,
    // top to bottom). Digits use the clock's 3×5 digits; anything else is
    // a gap.
    readonly property var letters: ({
            a: ["000", "000", "011", "101", "011", "000"],
            b: ["100", "100", "110", "101", "110", "000"],
            c: ["000", "000", "011", "100", "011", "000"],
            d: ["001", "001", "011", "101", "011", "000"],
            e: ["000", "000", "010", "111", "100", "000"],
            f: ["011", "010", "111", "010", "010", "000"],
            g: ["000", "000", "011", "101", "011", "110"],
            h: ["100", "100", "110", "101", "101", "000"],
            i: ["010", "000", "010", "010", "010", "000"],
            j: ["001", "000", "001", "001", "001", "110"],
            k: ["100", "100", "101", "110", "101", "000"],
            l: ["100", "100", "100", "100", "011", "000"],
            m: ["000", "000", "110", "111", "101", "000"],
            n: ["000", "000", "110", "101", "101", "000"],
            o: ["000", "000", "010", "101", "010", "000"],
            p: ["000", "000", "110", "101", "110", "100"],
            q: ["000", "000", "011", "101", "011", "001"],
            r: ["000", "000", "011", "100", "100", "000"],
            s: ["000", "000", "011", "010", "110", "000"],
            t: ["000", "010", "111", "010", "011", "000"],
            u: ["000", "000", "101", "101", "011", "000"],
            v: ["000", "000", "101", "101", "010", "000"],
            w: ["000", "000", "101", "111", "111", "000"],
            x: ["000", "000", "101", "010", "101", "000"],
            y: ["000", "000", "101", "101", "011", "110"],
            z: ["000", "000", "110", "010", "011", "000"]
        })

    // The username (whoever is logged in, read from $USER when the shell
    // starts), as written, as a strip of 6-dot columns with a blank column
    // between characters.
    readonly property var nameColumns: {
        var text = String(Quickshell.env("USER") || "user").toLowerCase();
        var out = [];
        for (var i = 0; i < text.length; i++) {
            var ch = text.charAt(i);
            var glyph = letters[ch] || (ch >= "0" && ch <= "9" ? digits[Number(ch)].concat(["000"]) : null);
            for (var c = 0; c < 3; c++) {
                var column = "";
                for (var rr = 0; rr < 6; rr++)
                    column += glyph ? glyph[rr].charAt(c) : "0";
                out.push(column);
            }
            out.push("000000");
        }
        return out;
    }

    function digitLit(value, x, y) {
        if (x < 0 || x > 2 || y < 0 || y > 4)
            return false;
        return digits[value][y].charAt(x) === "1";
    }

    // How lit the dot at (x, y) is from the pattern alone, from 0 to 1.
    function level(x, y, t, mode) {
        var cx = (cols - 1) / 2, cy = (rows - 1) / 2;
        var dx = x - cx, dy = y - cy;
        if (mode === 0) {
            var wave = 0.5 + 0.5 * Math.cos(Math.sqrt(dx * dx + dy * dy) * 1.1 - t * 0.4);
            return wave * wave * wave;
        }
        if (mode === 1) {
            var a = Math.atan2(dy, dx) - t * 0.12;
            a = ((a % (2 * Math.PI)) + 2 * Math.PI) % (2 * Math.PI);
            return Math.exp(-a * 1.4);
        }
        if (mode === 3) {
            // A heart that beats "lub-dub": it swells on each thump and
            // settles back.
            var p = t % 14;
            var beat = Math.exp(-p * 0.9) + (p >= 3 ? 0.6 * Math.exp(-(p - 3) * 0.9) : 0);
            var k = 5.4 * (0.84 + 0.16 * beat);
            var hx = dx / k, hy = -dy / k + 0.15;
            var f = Math.pow(hx * hx + hy * hy - 1, 3) - hx * hx * hy * hy * hy;
            return f <= 0 ? 1 : 0;
        }
        if (mode === 4) {
            // Hours over minutes, two 3×5 digits each, with a dot between
            // the rows blinking the seconds.
            var h = now.getHours(), m = now.getMinutes();
            var left = Math.round(cx) - 3, top = Math.round(cy) - 5;
            var col = x - left, row = y - top;
            var value = row < 5 ? h : m;
            var r = row < 5 ? row : row - 6;
            if (row === 5)
                return (col === 3 && now.getSeconds() % 2 === 0) ? 1 : 0;
            if (col >= 0 && col <= 2)
                return digitLit(Math.floor(value / 10), col, r) ? 1 : 0;
            if (col >= 4 && col <= 6)
                return digitLit(value % 10, col - 4, r) ? 1 : 0;
            return 0;
        }
        if (mode === 5) {
            // The name scrolls in from the right, then off to the left.
            var span = nameColumns.length + cols;
            var shift = Math.floor(t * 0.45) % span;
            var ci = x + shift - cols;
            var gr = y - (Math.round(cy) - 3);
            if (ci < 0 || ci >= nameColumns.length || gr < 0 || gr > 5)
                return 0;
            return nameColumns[ci].charAt(gr) === "1" ? 1 : 0;
        }
        if (mode === 6) {
            // An hourglass: a faint outline, sand draining from the top bulb
            // through the neck into the bottom one, then starting over.
            var ady = Math.abs(dy), adx = Math.abs(dx);
            var halfRows = Math.round(cy);
            if (ady === halfRows)
                return adx <= halfRows ? 0.3 : 0;         // caps
            if (adx > ady)
                return 0;
            if (adx === ady && ady > 0)
                return 0.3;                               // glass walls
            var period = 140;
            var progress = (t % period) / period;
            var bulb = halfRows - 1;                      // sand rows per bulb
            var topLevel = Math.ceil(bulb * (1 - progress));
            var bottomLevel = Math.ceil(bulb * progress);
            if (dy < 0)                                   // top: sits on the neck
                return -dy <= topLevel ? 1 : 0;
            if (dy > 0 && dy > bulb - bottomLevel)        // bottom: piles up
                return 1;
            // The falling stream, flickering down the middle.
            if (adx === 0 && progress > 0 && progress < 1 && (y + t) % 2 === 0)
                return 0.85;
            return 0;
        }
        var head = (t * (0.25 + 0.3 * hash(x)) + hash(x + 40) * 30) % (rows + 8);
        var d = head - y;
        return d >= 0 && d < 5 ? 1 - d / 5 : 0;
    }

    // What touch adds on top: the pointer's glow, burst rings and paint.
    function touch(index, x, y, t) {
        var v = 0;
        var hd = Math.hypot(x - hoverCol, y - hoverRow);
        if (hd < 2.5)
            v = Math.max(v, 0.7 * (1 - hd / 2.5));
        for (var i = 0; i < bursts.length; i++) {
            var age = t - bursts[i].at;
            if (age < 0 || age > 24)
                continue;
            var ring = Math.hypot(x - bursts[i].x, y - bursts[i].y) - age * 0.7;
            v = Math.max(v, Math.exp(-ring * ring * 1.5) * (1 - age / 24));
        }
        var at = painted[index];
        if (at !== undefined) {
            var fade = 1 - (t - at) / 40;
            if (fade <= 0)
                delete painted[index];
            else
                v = Math.max(v, fade);
        }
        return v;
    }

    // The control bar shows while the pointer is in the square. One mouse area
    // handles everything; `inside` resets when the panel stops running.
    readonly property bool shown: root.running && mouse.inside

    onRunningChanged: {
        if (!running)
            mouse.leave();
    }

    scale: mouse.pressed && !mouse.painting && !mouse.pressedButton ? 0.97 : 1

    Behavior on scale {
        SpatialMotion {
            fast: true
            bouncy: true
        }
    }

    Rectangle {
        id: plate
        anchors.fill: parent
        radius: Palette.Theme.radiusMedium
        color: Palette.Theme.surfaceContainerLow
    }

    StateLayer {
        radius: plate.radius
        tone: Palette.Theme.accent
        hovered: root.shown
        pressed: mouse.pressed && !mouse.painting && !mouse.pressedButton
    }

    Item {
        id: grid
        anchors.centerIn: parent
        width: root.pitch * root.cols
        height: root.pitch * root.rows

        Repeater {
            model: root.cols * root.rows

            Rectangle {
                id: dot
                required property int index
                readonly property int col: index % root.cols
                readonly property int row: Math.floor(index / root.cols)
                readonly property real reach: Math.hypot(Math.max(0, Math.abs(col - (root.cols - 1) / 2) - (root.cols - root.rows) / 2), row - (root.rows - 1) / 2)

                // Clip the grid to a capsule (a circle when square), like the
                // phone's round matrix.
                visible: reach <= root.rows / 2
                x: col * root.pitch + (root.pitch - width) / 2
                y: row * root.pitch + (root.pitch - height) / 2
                width: root.dotSize
                height: width
                radius: width / 2
                color: root.hue

                Behavior on color {
                    ColorMotion {}
                }
                opacity: 0.08 + 0.92 * Math.max(root.level(col, row, root.phase, root.mode), root.touch(index, col, row, root.tick))

                Behavior on opacity {
                    EffectMotion {}
                }
            }
        }
    }

    // The pattern's name, while hovered and briefly after it changes.
    Rectangle {
        anchors.top: parent.top
        anchors.topMargin: 6
        anchors.horizontalCenter: parent.horizontalCenter
        implicitWidth: nameText.implicitWidth + 14
        implicitHeight: 20
        radius: height / 2
        color: Qt.alpha(Palette.Theme.surfaceSolid, 0.85)
        opacity: root.shown || nameFlash.running ? 1 : 0

        Behavior on opacity {
            EffectMotion {}
        }

        Text {
            id: nameText
            anchors.centerIn: parent
            text: root.modeNames[root.mode] + (root.paused ? "  ·  paused" : "")
            color: Palette.Theme.textPrimary
            font.family: Palette.Theme.fontSans
            font.pixelSize: Palette.Theme.fontSizeXs
            font.weight: Font.DemiBold
        }

        Timer {
            id: nameFlash
            interval: 1200
        }
    }

    // Controls along the bottom edge, faded and nudged in while hovered.
    Rectangle {
        id: bar
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6
        implicitWidth: controls.implicitWidth + 8
        implicitHeight: 28
        radius: height / 2
        color: Qt.alpha(Palette.Theme.surfaceSolid, 0.9)
        opacity: root.shown ? 1 : 0
        transform: Translate {
            y: root.shown ? 0 : 6

            Behavior on y {
                EffectMotion {}
            }
        }

        Behavior on opacity {
            EffectMotion {}
        }

        Row {
            id: controls
            anchors.centerIn: parent
            spacing: 2

            BarButton {
                id: prevButton
                icon: "chevron_left"
                onClicked: root.setMode(root.mode - 1)
            }
            BarButton {
                id: pauseButton
                icon: root.paused ? "play_arrow" : "pause"
                on: root.paused
                onClicked: root.paused = !root.paused
            }
            BarButton {
                id: cycleButton
                icon: "autorenew"
                on: root.autoCycle
                onClicked: {
                    root.autoCycle = !root.autoCycle;
                    root.modeTicks = 0;
                }
            }
            BarButton {
                id: nextButton
                icon: "chevron_right"
                onClicked: root.setMode(root.mode + 1)
            }
        }
    }

    // On top of everything: the only mouse area in the panel.
    MouseArea {
        id: mouse

        property bool painting: false
        property real pressX: 0
        property real pressY: 0
        property Item hoveredButton: null
        property Item pressedButton: null
        property bool inside: false

        function leave() {
            inside = false;
            hoveredButton = null;
            root.hoverCol = -10;
            root.hoverRow = -10;
        }

        // The bar button under (x, y), if the bar is showing.
        function buttonAt(x, y) {
            if (!root.running)
                return null;
            var buttons = [prevButton, pauseButton, cycleButton, nextButton];
            for (var i = 0; i < buttons.length; i++) {
                var p = mapToItem(buttons[i], x, y);
                if (buttons[i].contains(p))
                    return buttons[i];
            }
            return null;
        }

        function overBar(x, y) {
            return root.running && bar.contains(mapToItem(bar, x, y));
        }

        // Pointer position in (fractional) cells, so the glow glides.
        function track(x, y) {
            if (overBar(x, y)) {
                root.hoverCol = -10;
                root.hoverRow = -10;
                return;
            }
            var p = mapToItem(grid, x, y);
            root.hoverCol = p.x / root.pitch - 0.5;
            root.hoverRow = p.y / root.pitch - 0.5;
        }

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: painting ? Qt.CrossCursor : Qt.PointingHandCursor

        onExited: leave()
        onPositionChanged: event => {
            inside = true;
            hoveredButton = buttonAt(event.x, event.y);
            track(event.x, event.y);
            if (pressed && !pressedButton && (event.buttons & Qt.LeftButton)) {
                if (!painting && Math.hypot(event.x - pressX, event.y - pressY) > 4)
                    painting = true;
                if (painting) {
                    var c = Math.round(root.hoverCol), r = Math.round(root.hoverRow);
                    if (c >= 0 && c < root.cols && r >= 0 && r < root.rows)
                        root.painted[r * root.cols + c] = root.tick;
                }
            }
        }
        onPressed: event => {
            painting = false;
            pressX = event.x;
            pressY = event.y;
            pressedButton = event.button === Qt.LeftButton ? buttonAt(event.x, event.y) : null;
        }
        onReleased: event => {
            var target = pressedButton;
            pressedButton = null;
            if (target) {
                if (target === buttonAt(event.x, event.y))
                    target.clicked();
            } else if (!painting && !overBar(event.x, event.y)) {
                if (event.button === Qt.RightButton) {
                    root.paused = !root.paused;
                } else {
                    root.burst(Math.round(root.hoverCol), Math.round(root.hoverRow));
                    root.setMode(root.mode + 1);
                }
            }
            painting = false;
        }
        onWheel: event => {
            var step = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x;
            if (step !== 0)
                root.setMode(root.mode + (step < 0 ? 1 : -1));
        }
    }

    // A small round button on the bar. It has no mouse area of its own; the
    // panel's one mouse area tells it when it's hovered or pressed.
    component BarButton: Item {
        id: button

        property string icon: ""
        property bool on: false
        readonly property bool hovered: mouse.hoveredButton === button
        readonly property bool down: mouse.pressedButton === button
        signal clicked

        implicitWidth: 24
        implicitHeight: 24
        scale: down ? 0.85 : 1

        Behavior on scale {
            SpatialMotion {
                fast: true
                bouncy: true
            }
        }

        StateLayer {
            radius: width / 2
            hovered: button.hovered
            pressed: button.down
        }

        Text {
            anchors.centerIn: parent
            text: button.icon
            color: button.on ? Palette.Theme.accent : (button.hovered ? Palette.Theme.textPrimary : Palette.Theme.textSecondary)
            font.family: Palette.Theme.fontIcons
            font.weight: Palette.Theme.iconWeight
            font.pixelSize: Palette.Theme.iconSizeSmall

            Behavior on color {
                ColorMotion {}
            }
        }
    }
}
