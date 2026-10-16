import Quickshell
import Quickshell.Io
import QtQuick
import "../theme" as Palette

// Settings → Customize, saved to JSON. Every value is clamped to a safe
// range; anything missing or invalid falls back to the stock default.
Item {
    id: root
    visible: false

    // The stock look; Reset brings these back.
    readonly property var defaults: ({
            roundness: 1.0,
            controlCenterWidth: 480,
            dockIconScale: 1.0,
            dockAutoHide: true,
            showGlyph: true,
            clockScale: 1.0,
            weatherScale: 1.0,
            cavaScale: 1.0,
            clockSeconds: false,
            clock24h: false
        })
    // [min, max] for the numeric settings.
    readonly property var ranges: ({
            roundness: [0, 1.5],
            controlCenterWidth: [420, 560],
            dockIconScale: [0.8, 1.3],
            clockScale: [0.8, 1.4],
            weatherScale: [0.8, 1.4],
            cavaScale: [0.8, 1.4]
        })

    function clean(key, value) {
        var fallback = defaults[key];
        if (typeof fallback === "boolean")
            return value === true || value === false ? value : fallback;
        var n = Number(value);
        if (value === undefined || value === null || !isFinite(n))
            return fallback;
        var r = ranges[key];
        n = Math.max(r[0], Math.min(r[1], n));
        // An even width keeps the control center's layout on whole pixels.
        return key === "controlCenterWidth" ? Math.round(n / 2) * 2 : n;
    }

    function get(key) {
        return clean(key, store[key]);
    }

    function set(key, value) {
        if (!(key in defaults))
            return;
        store[key] = clean(key, value);
        apply();
        saveTimer.restart();
    }

    function reset() {
        for (var key in defaults)
            store[key] = defaults[key];
        apply();
        saveTimer.restart();
    }

    // Pushes the (cleaned) values into the theme, where everything reads them.
    function apply() {
        Palette.Theme.roundness = get("roundness");
        Palette.Theme.controlCenterWidth = get("controlCenterWidth");
        Palette.Theme.dockIconScale = get("dockIconScale");
        Palette.Theme.dockAutoHide = get("dockAutoHide");
        Palette.Theme.showGlyph = get("showGlyph");
        Palette.Theme.clockScale = get("clockScale");
        Palette.Theme.weatherScale = get("weatherScale");
        Palette.Theme.cavaScale = get("cavaScale");
        Palette.Theme.clockSeconds = get("clockSeconds");
        Palette.Theme.clock24h = get("clock24h");
    }

    // Sliders change values many times a second; save once they settle.
    Timer {
        id: saveTimer
        interval: 400
        onTriggered: settingsFile.writeAdapter()
    }

    FileView {
        id: settingsFile
        path: Quickshell.cachePath("shell-settings.json")
        watchChanges: false
        blockLoading: true
        onLoaded: root.apply()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
            root.apply();
        }

        JsonAdapter {
            id: store
            property var roundness: 1.0
            property var controlCenterWidth: 480
            property var dockIconScale: 1.0
            property var dockAutoHide: true
            property var showGlyph: true
            property var clockScale: 1.0
            property var weatherScale: 1.0
            property var cavaScale: 1.0
            property var clockSeconds: false
            property var clock24h: false
        }
    }
}
