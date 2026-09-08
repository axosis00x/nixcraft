pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../../theme" as Palette

Item {
    id: root

    anchors.fill: parent
    visible: false
    focus: visible

    property real maxWidth: 4000
    property real maxHeight: 4000
    property var launcher: null
    property var controlCenter: null
    property var powerMenu: null
    property var themeService: null

    property string wallpapersRoot: Quickshell.env("HOME") + "/Pictures/wallpapers"
    property string activeTheme: ""
    property string wallpaperDir: activeTheme === "" ? "" : wallpapersRoot + "/" + activeTheme

    property var wallpapers: []
    property var filteredWallpapers: []
    property string currentWallpaper: ""

    // uniform scale knob — bump this up/down to resize the whole strip at once
    property real s: 1.0

    property int focusIndex: 0
    // continuous chased position — the strip renders from this, not focusIndex
    // directly, so keyboard autorepeat / wheel bursts stay smooth instead of
    // snapping tile-to-tile
    property real pos: 0

    property bool hintShown: false
    property bool cyclePending: false

    implicitWidth: Math.min(maxWidth - 32, Math.round(860 * root.s))
    implicitHeight: Math.round(170 * root.s)

    signal aboutToOpen
    signal aboutToClose

    Timer {
        id: closeTimer
        interval: 180
        onTriggered: root.visible = false
    }

    function open() {
        if (launcher && launcher.visible)
            launcher.closeLauncher(true);
        if (controlCenter && controlCenter.visible)
            controlCenter.closeControlCenter(true);
        if (powerMenu && powerMenu.visible)
            powerMenu.closePowerMenu(true);
        aboutToOpen();
        visible = true;
        hintShown = false;
        hintDwell.restart();
        refresh();
        forceActiveFocus();
    }

    function close(immediate) {
        if (!visible)
            return;
        aboutToClose();
        if (immediate) {
            closeTimer.stop();
            visible = false;
            return;
        }
        closeTimer.restart();
    }

    function show() {
        open();
    }

    function hide() {
        close();
    }

    function toggle() {
        if (visible)
            close();
        else
            open();
    }

    function cycle() {
        cyclePending = true;
        activeThemeProcess.running = true;
    }

    function chooseRandomWallpaper() {
        if (wallpapers.length === 0)
            return;
        var choices = wallpapers.filter(path => path !== currentWallpaper);
        if (choices.length === 0)
            choices = wallpapers;
        setWallpaper(choices[Math.floor(Math.random() * choices.length)]);
    }

    function move(delta) {
        if (filteredWallpapers.length === 0)
            return;
        focusIndex = Math.max(0, Math.min(filteredWallpapers.length - 1, focusIndex + delta));
    }

    function centerOnCurrent() {
        var idx = filteredWallpapers.indexOf(currentWallpaper);
        focusIndex = idx >= 0 ? idx : 0;
        pos = focusIndex;
    }

    function activate(shouldClose = false) {
        if (focusIndex < 0 || focusIndex >= filteredWallpapers.length)
            return;
        setWallpaper(filteredWallpapers[focusIndex]);
        if (shouldClose)
            root.close();
    }

    onVisibleChanged: {
        if (visible) {
            hintShown = false;
            hintDwell.restart();
            forceActiveFocus();
        }
    }

    onFocusIndexChanged: {
        hintShown = false;
        hintDwell.restart();
    }

    onFilteredWallpapersChanged: {
        if (focusIndex >= filteredWallpapers.length)
            focusIndex = Math.max(0, filteredWallpapers.length - 1);
    }

    Timer {
        id: hintDwell
        interval: 600
        onTriggered: root.hintShown = true
    }

    // chases `pos` toward `focusIndex` every frame — this is what gives the
    // strip its glide instead of an instant jump
    FrameAnimation {
        running: root.visible && root.pos !== root.focusIndex
        onTriggered: {
            var k = 1 - Math.exp(-frameTime / 0.07);
            var next = root.pos + (root.focusIndex - root.pos) * k;
            root.pos = Math.abs(next - root.focusIndex) < 0.001 ? root.focusIndex : next;
        }
    }

    IpcHandler {
        target: "wallpicker"

        function toggle(): void {
            root.toggle();
        }
        function open(): void {
            root.open();
        }
        function close(): void {
            root.close();
        }
        function cycle(): void {
            root.cycle();
        }
    }

    Process {
        id: listProcess

        command: ["find", root.wallpaperDir, "-maxdepth", "1", "-type", "f", "(", "-iname", "*.png", "-o", "-iname", "*.jpg", "-o", "-iname", "*.jpeg", "-o", "-iname", "*.webp", "-o", "-iname", "*.gif", ")"]

        stdout: StdioCollector {
            onStreamFinished: {
                let files = text.trim().length > 0 ? text.trim().split("\n") : [];

                root.wallpapers = files.sort();
                root.applyFilter();
                if (root.cyclePending) {
                    root.cyclePending = false;
                    root.chooseRandomWallpaper();
                }
            }
        }
    }

    Process {
        id: activeThemeProcess
        command: ["sh", "-c", "theme_file=$(sed -n 's/.*dofile(\"\\(.*\\)\").*/\\1/p' \"$HOME/.config/hypr/theme.lua\" | head -n 1); [ -n \"$theme_file\" ] && basename \"$(dirname \"$theme_file\")\""]

        stdout: StdioCollector {
            onStreamFinished: {
                root.activeTheme = text.trim();
                if (root.activeTheme === "") {
                    root.wallpapers = [];
                    root.applyFilter();
                    return;
                }
                listProcess.running = true;
            }
        }
    }

    function refresh() {
        activeThemeProcess.running = true;
        refreshCurrent();
    }

    function applyFilter() {
        filteredWallpapers = wallpapers;
        centerOnCurrent();
    }

    Process {
        id: currentWallpaperProcess
        command: ["sh", "-c", "find ~/.cache/awww -type f 2>/dev/null | head -1 | xargs cat 2>/dev/null | tr '\\0' '\\n' | grep '^/' | tail -1"]

        stdout: StdioCollector {
            onStreamFinished: {
                var path = text.trim();
                if (path.length > 0) {
                    root.currentWallpaper = path;
                    root.centerOnCurrent();
                }
            }
        }
    }

    Process {
        id: setWallpaperProcess
    }

    function setWallpaper(path) {
        root.currentWallpaper = path;

        // The dynamic theme's whole palette is derived from its wallpaper,
        // so picking a new one has to go through wallust (via apply-theme.sh)
        // rather than just swapping the image.
        if (root.activeTheme === "dynamic" && root.themeService) {
            root.themeService.apply("dynamic", path);
            return;
        }

        setWallpaperProcess.command = ["awww", "img", path, "--transition-type", "center", "--transition-duration", "0.7", "--transition-fps", "60"];

        setWallpaperProcess.running = true;
    }

    function refreshCurrent() {
        currentWallpaperProcess.running = true;
    }

    Keys.onLeftPressed: event => {
        root.move(-1);
        event.accepted = true;
    }
    Keys.onRightPressed: event => {
        root.move(1);
        event.accepted = true;
    }
    Keys.onUpPressed: event => {
        root.move(-1);
        event.accepted = true;
    }
    Keys.onDownPressed: event => {
        root.move(1);
        event.accepted = true;
    }
    Keys.onReturnPressed: event => {
        root.activate(true);
        event.accepted = true;
    }
    Keys.onEnterPressed: event => {
        root.activate(true);
        event.accepted = true;
    }
    Keys.onEscapePressed: event => {
        root.close();
        event.accepted = true;
    }

    Item {
        id: panel
        anchors.fill: parent
        clip: true

        // depth slots: index 0 = focused tile, index 4 = furthest tuned slot,
        // anything past that extrapolates linearly and fades to invisible
        readonly property var slotW: [196, 126, 104, 88, 74]
        readonly property var slotH: [110, 71, 59, 50, 42]
        readonly property var slotCX: [0, 143, 244, 326, 393]
        readonly property var slotBright: [1, 0.56, 0.42, 0.30, 0.22]
        readonly property var slotSat: [1, 0.65, 0.55, 0.45, 0.40]

        function slotLerp(arr, ao) {
            if (ao >= 4)
                return arr[4];
            var i = Math.floor(ao);
            var f = ao - i;
            return arr[i] + (arr[i + 1] - arr[i]) * f;
        }

        function offsetX(off) {
            var ao = Math.abs(off);
            var cx = ao <= 4 ? slotLerp(slotCX, ao) : slotCX[4] + (ao - 4) * 60;
            return (off < 0 ? -cx : cx) * root.s;
        }

        Item {
            id: keyHandler
            anchors.fill: parent
            focus: root.visible

            Keys.onLeftPressed: event => {
                root.move(-1);
                event.accepted = true;
            }
            Keys.onRightPressed: event => {
                root.move(1);
                event.accepted = true;
            }
            Keys.onUpPressed: event => {
                root.move(-1);
                event.accepted = true;
            }
            Keys.onDownPressed: event => {
                root.move(1);
                event.accepted = true;
            }
            Keys.onReturnPressed: event => {
                root.activate(true);
                event.accepted = true;
            }
            Keys.onEnterPressed: event => {
                root.activate(true);
                event.accepted = true;
            }
            Keys.onEscapePressed: event => {
                root.close();
                event.accepted = true;
            }

            Repeater {
                model: root.filteredWallpapers

                delegate: Item {
                    id: tile

                    required property int index
                    required property var modelData

                    readonly property real off: index - panel.pos_
                    readonly property real ao: Math.abs(off)
                    readonly property bool focused: index === root.focusIndex
                    readonly property bool isActiveWallpaper: modelData === root.currentWallpaper
                    readonly property real bright: tile.visible ? panel.slotLerp(panel.slotBright, ao) : 0
                    readonly property real sat: tile.visible ? panel.slotLerp(panel.slotSat, ao) : 1
                    readonly property real corner: tile.visible ? (8 + 2 * Math.max(0, 1 - ao)) * root.s : 8

                    readonly property real edgeFade: {
                        if (!tile.visible)
                            return 0;
                        var soft = 70 * root.s;
                        var gap = Math.min(x, panel.width - (x + width));
                        return Math.max(0, Math.min(1, gap / soft));
                    }

                    width: tile.visible ? panel.slotLerp(panel.slotW, ao) * root.s : 0
                    height: tile.visible ? panel.slotLerp(panel.slotH, ao) * root.s : 0
                    x: tile.visible ? (panel.width / 2 + panel.offsetX(off) - width / 2) : 0
                    y: tile.visible ? ((panel.height - height) / 2) : 0
                    z: 10 - ao
                    visible: ao <= 5
                    opacity: edgeFade * (ao <= 4 ? 1 : Math.max(0, 5 - ao))

                    Rectangle {
                        id: card
                        anchors.fill: parent
                        radius: tile.corner
                        color: Palette.Theme.surfaceContainerHigh
                        clip: true

                        layer.enabled: tile.visible && (tile.focused || Math.abs(tile.sat - 1) > 0.02)
                        layer.effect: MultiEffect {
                            saturation: tile.sat - 1
                            shadowEnabled: tile.focused
                            shadowColor: Qt.rgba(0, 0, 0, 0.35)
                            shadowBlur: 0.7
                            shadowVerticalOffset: 4 * root.s
                        }

                        Image {
                            anchors.fill: parent
                            source: tile.ao <= 6 ? ("file://" + tile.modelData) : ""
                            sourceSize.width: 512
                            sourceSize.height: 220
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            smooth: true
                            cache: true
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: Qt.rgba(0, 0, 0, 1)
                            opacity: 1 - tile.bright
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 6 * root.s
                            width: 22 * root.s
                            height: 22 * root.s
                            radius: width / 2
                            visible: tile.isActiveWallpaper
                            color: Palette.Theme.accent

                            Text {
                                anchors.centerIn: parent
                                text: "\u2713"
                                color: "white"
                                font.pixelSize: 13 * root.s
                                font.bold: true
                            }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: tile.corner
                        color: "transparent"
                        border.width: 1
                        border.color: tile.focused ? Palette.Theme.accent + "66" : "transparent"

                        Behavior on border.color {
                            ColorAnimation {
                                duration: 160
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!tile.focused)
                                root.focusIndex = tile.index;
                            else
                                root.activate(false);
                        }
                    }
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: root.filteredWallpapers.length === 0
            text: "no wallpapers found in " + root.wallpaperDir
            color: Palette.Theme.textMuted
            font.family: Palette.Theme.fontMono
            font.pixelSize: 12
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8 * root.s
            visible: root.filteredWallpapers.length > 0
            opacity: root.hintShown ? 1 : 0
            text: "click to set · arrows to browse"
            color: Palette.Theme.textMuted
            font.family: Palette.Theme.fontMono
            font.pixelSize: 10 * root.s

            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                }
            }
        }

        // exposes panel.pos so tiles above can read `off` without root having
        // to forward it manually — mirrors root.pos in the reference
        property alias pos_: root.pos

        MouseArea {
            id: wheelArea
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            property real acc: 0
            onWheel: event => {
                acc += event.angleDelta.y / 120;
                const notches = Math.trunc(acc);
                if (notches !== 0) {
                    root.move(-notches);
                    acc -= notches;
                }
                event.accepted = true;
            }
        }
    }
}
