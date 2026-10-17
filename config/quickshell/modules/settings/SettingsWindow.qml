pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../components/material"
import "../../services"
import "../controlcenter"
import "../../theme" as Palette

// System settings as a normal floating window: a menu on the left, the
// selected page on the right. Changes go through the control center's handlers.
FloatingWindow {
    id: root

    property var controlCenter: null
    property var widgetsService: null
    property var themeService: null
    property var barLayout: null
    property var shellSettings: null

    property string page: "overview"
    property string query: ""

    readonly property string activePage: query.trim() !== "" ? "search" : page

    property bool shown: false

    signal aboutToOpen

    // Resolution, scale and mirroring (Display page).
    readonly property alias displayService: displayService

    DisplayService {
        id: displayService
    }

    readonly property real cardWidth: 860
    readonly property real cardHeight: 560

    // Matched by the Hyprland window rule.
    title: "nixcraft-settings"
    visible: shown
    color: "transparent"
    implicitWidth: cardWidth
    implicitHeight: cardHeight
    // Resizable (no fixed size), so Hyprland can tile it; Super+V toggles.
    minimumSize: Qt.size(640, 420)

    // The window can also be closed by the compositor (e.g. SUPER+Q).
    onVisibleChanged: {
        if (!visible)
            shown = false;
    }

    // So summaries (also shown by the launcher's /settings list) are filled
    // in before the window is ever opened.
    Component.onCompleted: aboutProcess.running = true

    readonly property var pageIds: ["overview", "network", "display", "sound", "power", "themes", "appearance", "widgets", "about", "search"]

    // ── open / close ────────────────────────────────────────────────
    IpcHandler {
        target: "settings"
        function toggle(): void {
            root.shown ? root.close() : root.open();
        }
        function open(): void {
            root.open();
        }
        function close(): void {
            root.close();
        }
        function openPage(name: string): void {
            root.openPage(name);
        }
    }

    function open() {
        if (shown)
            return;
        query = "";
        aboutToOpen();
        shown = true;
        // This FloatingWindow instance is kept alive while hidden. If the
        // user tiled it before closing, the map rule will not run again, so
        // explicitly restore its floating state after Hyprland maps it.
        restoreFloatingTimer.restart();
        if (controlCenter)
            controlCenter.refreshAll();
        if (themeService)
            themeService.refresh();
        aboutProcess.running = true;
        searchInput.forceActiveFocus();
    }

    function restoreFloating() {
        floatWindowProcess.exec(["hyprctl", "eval", "hl.dispatch(hl.dsp.window.float({window = \"title:nixcraft-settings\", action = \"on\"})); hl.dispatch(hl.dsp.window.center({window = \"title:nixcraft-settings\"}))"]);
    }

    Timer {
        id: restoreFloatingTimer
        interval: 100
        repeat: false
        onTriggered: root.restoreFloating()
    }

    Process {
        id: floatWindowProcess
    }

    function openPage(name) {
        open();
        if (name === "bar" || name === "dock")
            name = "appearance";
        if (pageIds.indexOf(name) !== -1 && name !== "search")
            page = name;
    }

    function close() {
        shown = false;
        searchInput.text = "";
    }

    // Up/Down step through the sidebar pages (wrapping); clears any search.
    function stepPage(delta) {
        var i = 0;
        for (var k = 0; k < categories.length; k++) {
            if (categories[k].id === page)
                i = k;
        }
        searchInput.text = "";
        page = categories[(i + delta + categories.length) % categories.length].id;
    }

    // Escape peels back one layer: search text first, then the window.
    function back() {
        if (searchInput.text !== "")
            searchInput.text = "";
        else
            close();
    }

    // ── live state (all delegated to the control center) ────────────
    function flag(key) {
        var c = controlCenter;
        if (key === "dockautohide")
            return shellSettings ? shellSettings.get("dockAutoHide") : true;
        if (key === "glyph")
            return shellSettings ? shellSettings.get("showGlyph") : true;
        if (key === "clockseconds" || key === "clock24h")
            return shellSettings ? shellSettings.get(shellFlagKey[key]) : false;
        switch (key) {
        case "wifi":
            return c ? c.wifiEnabled : false;
        case "bluetooth":
            return c ? c.bluetoothEnabled : false;
        case "airplane":
            return c ? (!c.wifiEnabled && !c.bluetoothEnabled) : false;
        case "dnd":
            return c ? c.dndEnabled : false;
        case "nightlight":
            return c ? c.hyprsunsetEnabled : false;
        case "keepawake":
            return c ? c.keepAwake : false;
        case "mute":
            return c ? c.volumeMuted : false;
        case "micmute":
            return c ? c.micMuted : false;
        case "dock":
        case "clock":
        case "weather":
        case "cava":
            return widgetsService ? widgetsService.isEnabled(key) : false;
        case "island":
            return barLayout ? barLayout.island : false;
        case "mirror":
            return displayService.mirror;
        default:
            return false;
        }
    }

    // ── confirmations ───────────────────────────────────────────────
    // Layout changes (customization sliders, bar style) apply as a preview
    // and a bar asks to Save or Cancel. Toggles and system settings (Wi-Fi,
    // volume, night light...) apply directly, with no prompt.
    readonly property var confirmLevels: ["roundness", "dockicons", "ccwidth", "clocksize", "weathersize", "cavasize"]
    readonly property var confirmChoices: ["barstyle"]
    // Switch rows backed by ShellSettings → their keys.
    readonly property var shellFlagKey: ({
            dockautohide: "dockAutoHide",
            glyph: "showGlyph",
            clockseconds: "clockSeconds",
            clock24h: "clock24h"
        })
    readonly property var widgetScaleKey: ({
            clocksize: "clockScale",
            weathersize: "weatherScale",
            cavasize: "cavaScale"
        })
    property var pending: ({}) // key -> { kind, original }
    readonly property int pendingCount: Object.keys(pending).length
    // A question with its own confirm button (e.g. Reset), or a short note.
    property string promptText: ""
    property string promptAction: ""
    property var promptCallback: null
    property string noteText: ""

    function track(key, kind, original) {
        if (pending[key] !== undefined)
            return;
        var next = Object.assign({}, pending);
        next[key] = { kind: kind, original: original };
        pending = next;
    }

    function savePending() {
        pending = {};
    }

    function cancelPending() {
        var list = pending;
        pending = {};
        for (var key in list) {
            var p = list[key];
            if (p.kind === "flag")
                applyFlag(key, p.original);
            else if (p.kind === "choice")
                applyChoice(key, p.original);
            else
                applyLevel(key, p.original);
        }
    }

    function ask(text, action, callback) {
        promptText = text;
        promptAction = action;
        promptCallback = callback;
    }

    function note(text) {
        noteText = text;
        noteTimer.restart();
    }

    Timer {
        id: noteTimer
        interval: 2500
        onTriggered: root.noteText = ""
    }

    function rowFor(key) {
        for (var id in pageSections) {
            var sections = pageSections[id];
            for (var i = 0; i < sections.length; i++) {
                var rows = sections[i].rows || [];
                for (var j = 0; j < rows.length; j++) {
                    if (rows[j].key === key)
                        return rows[j];
                }
            }
        }
        return null;
    }

    // "Island mode on", "Bar style: Compact", "Corner radius 13 px".
    function describe(key) {
        var row = rowFor(key);
        var title = row ? row.title : key;
        var p = pending[key];
        if (!p)
            return title;
        if (p.kind === "flag")
            return title + (flag(key) ? " on" : " off");
        if (p.kind === "choice") {
            var option = row && row.options ? row.options.find(o => o.id === choice(key)) : null;
            return title + ": " + (option ? option.label : choice(key));
        }
        return title + " " + (levelText(key) || Math.round(level(key) * 100) + "%");
    }

    readonly property string noticeText: promptText !== "" ? promptText : (pendingCount === 1 ? describe(Object.keys(pending)[0]) : (pendingCount > 1 ? pendingCount + " unsaved changes" : noteText))

    function setFlag(key, on) {
        if (flag(key) !== on)
            applyFlag(key, on);
    }

    function setChoice(key, id) {
        if (choice(key) === id)
            return;
        if (confirmChoices.indexOf(key) !== -1)
            track(key, "choice", choice(key));
        applyChoice(key, id);
    }

    function setLevel(key, value) {
        if (Math.abs(level(key) - value) < 0.001)
            return;
        if (confirmLevels.indexOf(key) !== -1)
            track(key, "level", level(key));
        applyLevel(key, value);
    }

    function applyFlag(key, on) {
        var c = controlCenter;
        if (flag(key) === on)
            return;
        if (shellFlagKey[key]) {
            if (shellSettings)
                shellSettings.set(shellFlagKey[key], on);
            return;
        }
        switch (key) {
        case "wifi":
            c.toggleWifi();
            break;
        case "bluetooth":
            c.toggleBluetooth();
            break;
        case "airplane":
            if (on) {
                if (c.wifiEnabled)
                    c.toggleWifi();
                if (c.bluetoothEnabled)
                    c.toggleBluetooth();
            } else if (!c.wifiEnabled) {
                c.toggleWifi();
            }
            break;
        case "dnd":
            c.toggleDnd();
            break;
        case "nightlight":
            c.toggleHyprsunset();
            break;
        case "keepawake":
            c.toggleKeepAwake();
            break;
        case "mute":
            c.toggleMute();
            break;
        case "micmute":
            c.toggleMicMute();
            break;
        case "dock":
        case "clock":
        case "weather":
        case "cava":
            if (widgetsService)
                widgetsService.toggle(key);
            break;
        case "island":
            if (barLayout)
                barLayout.setIsland(on);
            break;
        case "mirror":
            displayService.setMirror(on);
            break;
        }
    }

    function level(key) {
        var c = controlCenter;
        if (!c && key !== "cpu" && key !== "ram")
            return 0;
        switch (key) {
        case "volume":
            return c.volumeValue;
        case "brightness":
            return c.brightnessValue;
        case "mic":
            return c.micValue;
        case "cpu":
            return cpuUsage;
        case "ram":
            return memUsage;
        case "roundness":
            return shellSettings ? shellSettings.get("roundness") / 1.5 : 1 / 1.5;
        case "dockicons":
            return shellSettings ? (shellSettings.get("dockIconScale") - 0.8) / 0.5 : 0.4;
        case "ccwidth":
            return shellSettings ? (shellSettings.get("controlCenterWidth") - 420) / 140 : 0.43;
        case "clocksize":
        case "weathersize":
        case "cavasize":
            return shellSettings ? (shellSettings.get(widgetScaleKey[key]) - 0.8) / 0.6 : 1 / 3;
        case "nightwarmth":
            // 4500 K (barely warm) .. 1900 K (very warm), warmer to the right.
            return (4500 - c.nightTemperature) / 2600;
        case "nightgamma":
            return (c.nightGamma - 50) / 50;
        default:
            return 0;
        }
    }

    // A typed value (e.g. "480 px", "2800 K", "80%") for a slider, in its own unit.
    function enterLevel(key, text) {
        var n = parseFloat(String(text).replace(",", "."));
        if (isNaN(n))
            return;
        var v = ({
                roundness: n / 19.5,
                dockicons: (n / 28 - 0.8) / 0.5,
                ccwidth: (n - 420) / 140,
                clocksize: (n / 248 - 0.8) / 0.6,
                weathersize: (n / 248 - 0.8) / 0.6,
                cavasize: (n / 320 - 0.8) / 0.6,
                nightwarmth: (4500 - n) / 2600,
                nightgamma: (n - 50) / 50
            })[key];
        if (v !== undefined)
            setLevel(key, Math.max(0, Math.min(1, v)));
    }

    // Where a slider's default sits on its track (0–1), shown as a tick;
    // -1 for none.
    function levelDefault(key) {
        switch (key) {
        case "roundness":
            return 1 / 1.5;
        case "dockicons":
            return 0.4;
        case "ccwidth":
            return 60 / 140;
        case "clocksize":
        case "weathersize":
        case "cavasize":
            return 0.2 / 0.6;
        case "nightwarmth":
            return 1700 / 2600;
        case "nightgamma":
            return 0.7;
        default:
            return -1;
        }
    }

    // A slider's label when a percentage of its track isn't the real value.
    function levelText(key) {
        var c = controlCenter;
        if (shellSettings) {
            if (key === "roundness")
                return Math.round(shellSettings.get("roundness") * 13) + " px";
            if (key === "dockicons")
                return Math.round(shellSettings.get("dockIconScale") * 28) + " px";
            if (key === "ccwidth")
                return shellSettings.get("controlCenterWidth") + " px";
            if (key === "clocksize" || key === "weathersize")
                return Math.round(shellSettings.get(widgetScaleKey[key]) * 248) + " px";
            if (key === "cavasize")
                return Math.round(shellSettings.get(widgetScaleKey[key]) * 320) + " px";
        }
        if (key === "nightwarmth" && c)
            return c.nightTemperature + " K";
        if (key === "nightgamma" && c)
            return c.nightGamma + "%";
        return "";
    }

    function applyLevel(key, value) {
        var c = controlCenter;
        if (shellSettings) {
            if (key === "roundness")
                return shellSettings.set("roundness", value * 1.5);
            if (key === "dockicons")
                return shellSettings.set("dockIconScale", 0.8 + value * 0.5);
            if (key === "ccwidth")
                return shellSettings.set("controlCenterWidth", 420 + value * 140);
            if (widgetScaleKey[key])
                return shellSettings.set(widgetScaleKey[key], 0.8 + value * 0.6);
        }
        if (!c)
            return;
        switch (key) {
        case "volume":
            c.setVolume(value);
            break;
        case "brightness":
            c.setBrightness(value);
            break;
        case "mic":
            c.setMic(value);
            break;
        case "nightwarmth":
            c.setNightTone(4500 - value * 2600, c.nightGamma);
            break;
        case "nightgamma":
            c.setNightTone(c.nightTemperature, 50 + value * 50);
            break;
        }
    }

    function choice(key) {
        if (key === "powerprofile")
            return controlCenter ? controlCenter.powerProfile : "";
        if (key === "barstyle")
            return barLayout ? barLayout.style : "";
        return "";
    }

    function applyChoice(key, id) {
        if (key === "powerprofile" && controlCenter)
            controlCenter.setPowerProfile(id);
        else if (key === "barstyle" && barLayout)
            barLayout.setStyle(id);
    }

    // Battery comes straight from sysfs (same source as the bar) — UPower
    // isn't running on this system.
    readonly property int batteryPercent: about.battery !== undefined && about.battery !== "" ? parseInt(about.battery) : -1
    readonly property bool batteryCharging: about.batstatus === "Charging"

    readonly property var profileNames: ({
            "power-saver": "Power saver",
            "balanced": "Balanced",
            "performance": "Performance"
        })

    function pct(v) {
        return Math.round(v * 100) + "%";
    }

    // Short live summaries shown under each category on the home list.
    function subtitleFor(key) {
        var c = controlCenter;
        switch (key) {
        case "bar":
        case "dock":
            return (barLayout ? "Bar: " + barLayout.style + (flag("island") ? ", island" : "") + "  ·  " : "") + "Control center " + levelText("ccwidth") + "  ·  " + (flag("dock") ? (flag("dockautohide") ? "Dock hides over windows" : "Dock always shown") : "Dock hidden");
        case "widgets":
            return ["clock", "weather", "cava"].filter(k => flag(k)).length + " of 3 widgets on";
        case "net":
            return "Wi-Fi " + (flag("wifi") ? "on" : "off") + "  ·  Bluetooth " + (flag("bluetooth") ? "on" : "off");
        case "display":
            return "Brightness " + pct(level("brightness")) + (flag("nightlight") ? "  ·  Night light on" : "");
        case "sound":
            return flag("mute") ? "Muted" : "Volume " + pct(level("volume"));
        case "power":
            return (batteryPercent >= 0 ? batteryPercent + "%" + (batteryCharging ? " charging" : "") + "  ·  " : "") + (profileNames[choice("powerprofile")] || "");
        case "appearance":
            return "Bar, control center and dock";
        case "themes":
            return themeService && themeService.activeTheme ? "Theme: " + themeService.activeTheme : "Theme, wallpaper and corners";
        case "about":
            return about.host || "This device";
        case "mirror":
            if (!displayService.external)
                return "Applies when a second display is connected";
            return displayService.mirror ? "Built-in display shows " + displayService.mirrorSource : "Extend the desktop across both";
        default:
            return "";
        }
    }

    property var about: ({})

    function infoFor(key) {
        switch (key) {
        case "cpu":
            return cpuThreads > 0 ? cpuThreads + " threads" : "";
        case "ram":
            return memTotalKb > 0 ? gb(memTotalKb - memAvailKb) + " of " + gb(memTotalKb) + " GB" : "";
        case "battery":
            return batteryPercent >= 0 ? batteryPercent + "%" + (batteryCharging ? " · charging" : "") : "No battery";
        default:
            return about[key] || "…";
        }
    }

    // Live CPU, memory, disk and temperature for the gauges on the power
    // page; polls only while that page is on screen.
    SystemStats {
        id: systemStats
        running: root.shown && root.page === "power"
    }
    property alias stats: systemStats

    // ── system usage ────────────────────────────────────────────────
    // CPU is the busy share of jiffies between two /proc/stat samples; RAM
    // is MemTotal minus MemAvailable. Sampled only while the window is open.
    property real cpuUsage: 0
    property real memUsage: 0
    property real memTotalKb: 0
    property real memAvailKb: 0
    property var cpuPrev: null
    property int cpuThreads: 0

    function gb(kb) {
        return (kb / 1048576).toFixed(1);
    }

    Timer {
        interval: 2000
        repeat: true
        triggeredOnStart: true
        running: root.shown
        onTriggered: usageProcess.running = true
    }

    Process {
        id: usageProcess
        command: ["sh", "-c", "head -n1 /proc/stat; grep -E '^(MemTotal|MemAvailable):' /proc/meminfo; echo threads $(nproc)"]
        stdout: StdioCollector {
            onStreamFinished: {
                text.split("\n").forEach(line => {
                    var f = line.trim().split(/\s+/);
                    if (f[0] === "cpu") {
                        var v = f.slice(1).map(Number);
                        var idle = v[3] + (v[4] || 0);
                        var total = v.reduce((a, b) => a + b, 0);
                        var prev = root.cpuPrev;
                        if (prev && total > prev.total)
                            root.cpuUsage = 1 - (idle - prev.idle) / (total - prev.total);
                        root.cpuPrev = { idle: idle, total: total };
                    } else if (f[0] === "MemTotal:") {
                        root.memTotalKb = Number(f[1]);
                    } else if (f[0] === "MemAvailable:") {
                        root.memAvailKb = Number(f[1]);
                    } else if (f[0] === "threads") {
                        root.cpuThreads = Number(f[1]);
                    }
                });
                if (root.memTotalKb > 0)
                    root.memUsage = 1 - root.memAvailKb / root.memTotalKb;
            }
        }
    }

    Process {
        id: aboutProcess
        command: ["sh", "-c", "echo host=$(hostname); echo os=$(. /etc/os-release; echo \"$PRETTY_NAME\"); echo kernel=$(uname -r); echo uptime=$(awk '{d=int($1/86400); h=int(($1%86400)/3600); m=int(($1%3600)/60); s=\"\"; if(d>0) s=d \"d \"; if(h>0||d>0) s=s h \"h \"; printf \"%s%dm\", s, m}' /proc/uptime); echo user=$USER; echo battery=$(cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n1); echo batstatus=$(cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -n1)"]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = {};
                text.split("\n").forEach(line => {
                    var i = line.indexOf("=");
                    if (i > 0)
                        out[line.slice(0, i)] = line.slice(i + 1);
                });
                root.about = out;
            }
        }
    }

    function activate(spec) {
        // A search hit for an inline gallery jumps to the page that holds it.
        if (spec.page) {
            searchInput.text = "";
            page = spec.page;
            return;
        }
        if (spec.act === "pfp" || spec.act === "pfpreset") {
            Quickshell.execDetached([Quickshell.env("HOME") + "/.config/quickshell/scripts/pfp.sh", spec.act === "pfp" ? "pick" : "reset"]);
            return;
        }
        if (spec.act === "resetcustom" && shellSettings) {
            ask("Reset layout settings to stock?", "Reset", () => {
                savePending();
                shellSettings.reset();
                note("Layout settings reset");
            });
            return;
        }
        var c = controlCenter;
        if (spec.act === "clearnotifs" && c)
            c.clearAllNotifications();
        else if (spec.act === "mixer" && c)
            c.openWiremix();
    }

    // ── content ─────────────────────────────────────────────────────
    readonly property var categories: [
        { id: "overview", icon: "", title: "Overview", sub: "overview" },
        { id: "themes", icon: "", title: "Themes", sub: "themes" },
        { id: "appearance", icon: "tune", title: "Appearance", sub: "appearance" },
        { id: "widgets", icon: "widgets", title: "Widgets", sub: "widgets" },
        { id: "network", icon: "", title: "Network & internet", sub: "net" },
        { id: "display", icon: "", title: "Display", sub: "display" },
        { id: "sound", icon: "", title: "Sound", sub: "sound" },
        { id: "power", icon: "", title: "Power & performance", sub: "power" },
        { id: "about", icon: "", title: "About device", sub: "about" }
    ]

    readonly property var pageTitles: ({
            "overview": "Overview",
            "network": "Network & internet",
            "display": "Display",
            "sound": "Sound",
            "power": "Power & performance",
            "themes": "Themes",
            "appearance": "Appearance",
            "widgets": "Widgets",
            "about": "About device",
            "search": "Search results"
        })

    function pageSummary(id) {
        if (id === "overview")
            return about.os ? about.os + (about.host ? "  ·  " + about.host : "") : "Quick settings and levels";
        if (id === "search")
            return sectionsFor("search").length ? "Matching settings from every page" : "Nothing matches your search";
        for (var i = 0; i < categories.length; i++) {
            if (categories[i].id === id)
                return subtitleFor(categories[i].sub);
        }
        return "";
    }

    readonly property var pageSections: ({
            "overview": [
                {
                    title: "Quick settings",
                    layout: "tiles",
                    rows: [
                        { kind: "switch", key: "wifi", icon: "", title: "Wi-Fi" },
                        { kind: "switch", key: "bluetooth", icon: "", title: "Bluetooth" },
                        { kind: "switch", key: "dnd", icon: "", title: "Do not disturb" },
                        { kind: "switch", key: "nightlight", icon: "", title: "Night light" },
                        { kind: "switch", key: "keepawake", icon: "", title: "Keep awake" },
                        { kind: "switch", key: "dock", icon: "", title: "Dock" }
                    ]
                },
                {
                    title: "Levels",
                    rows: [
                        { kind: "slider", key: "brightness", icon: "", title: "Brightness" },
                        { kind: "slider", key: "volume", icon: "", title: "Volume" },
                        { kind: "slider", key: "mic", icon: "", title: "Microphone" }
                    ]
                }
            ],
            "network": [
                {
                    title: "Connections",
                    rows: [
                        { kind: "switch", key: "wifi", icon: "", title: "Wi-Fi" },
                        { kind: "switch", key: "bluetooth", icon: "", title: "Bluetooth" },
                        { kind: "switch", key: "airplane", icon: "", title: "Airplane mode", subtitle: "Turns off Wi-Fi and Bluetooth" }
                    ]
                }
            ],
            "display": [
                {
                    title: "Brightness",
                    rows: [
                        { kind: "slider", key: "brightness", icon: "", title: "Brightness level" },
                        { kind: "switch", key: "nightlight", icon: "", title: "Night light", subtitle: "Warmer colors at night" },
                        { kind: "slider", key: "nightwarmth", icon: "thermostat", title: "Night light warmth" },
                        { kind: "slider", key: "nightgamma", icon: "contrast", title: "Night light gamma" }
                    ]
                },
                {
                    title: "Displays",
                    layout: "displays",
                    rows: [
                        { kind: "nav", page: "display", icon: "monitor", title: "Resolution", subtitle: "Screen resolution and refresh rate" },
                        { kind: "nav", page: "display", icon: "zoom_in", title: "Display scale", subtitle: "Make everything bigger or smaller" }
                    ]
                },
                {
                    title: "Multiple displays",
                    rows: [
                        { kind: "switch", key: "mirror", icon: "screen_share", title: "Mirror displays", sub: "mirror" }
                    ]
                }
            ],
            "sound": [
                {
                    title: "Volume",
                    rows: [
                        { kind: "slider", key: "volume", icon: "", title: "Media volume" },
                        { kind: "switch", key: "mute", icon: "", title: "Mute" }
                    ]
                },
                {
                    title: "Microphone",
                    rows: [
                        { kind: "slider", key: "mic", icon: "", title: "Microphone level" },
                        { kind: "switch", key: "micmute", icon: "", title: "Mute microphone" }
                    ]
                },
                {
                    title: "",
                    rows: [
                        { kind: "nav", act: "mixer", icon: "", title: "Audio mixer", subtitle: "Open per-app volume controls" }
                    ]
                }
            ],
            "power": [
                {
                    title: "Power mode",
                    rows: [
                        {
                            kind: "segment", key: "powerprofile", title: "Performance profile",
                            options: [
                                { id: "power-saver", label: "Saver" },
                                { id: "balanced", label: "Balanced" },
                                { id: "performance", label: "Performance" }
                            ]
                        }
                    ]
                },
                {
                    title: "Battery",
                    rows: [
                        { kind: "info", key: "battery", icon: "", title: "Battery level" },
                        { kind: "switch", key: "keepawake", icon: "", title: "Keep screen awake", subtitle: "Prevent the screen from locking or sleeping" }
                    ]
                },
                {
                    title: "System usage",
                    layout: "usage",
                    rows: [
                        { kind: "nav", page: "power", icon: "memory", title: "CPU usage" },
                        { kind: "nav", page: "power", icon: "memory_alt", title: "Memory usage" },
                        { kind: "nav", page: "power", icon: "hard_drive", title: "Disk usage" },
                        { kind: "nav", page: "power", icon: "thermostat", title: "Temperature" }
                    ]
                }
            ],
            "appearance": [
                {
                    title: "Layout",
                    rows: [
                        {
                            kind: "segment", key: "barstyle", title: "Bar style",
                            options: [
                                { id: "top", label: "Top" },
                                { id: "compact", label: "Compact" },
                                { id: "left", label: "Left" }
                            ]
                        },
                        { kind: "switch", key: "island", icon: "rounded_corner", title: "Island mode", subtitle: "Float the notch and its panels as rounded islands" }
                    ]
                },
                {
                    title: "Shape",
                    rows: [
                        { kind: "slider", key: "roundness", icon: "rounded_corner", title: "Corner roundness" }
                    ]
                },
                {
                    title: "Control center",
                    rows: [
                        { kind: "slider", key: "ccwidth", icon: "width", title: "Control center width" },
                        { kind: "switch", key: "glyph", icon: "grid_view", title: "Glyph matrix", subtitle: "The animated dot display in Controls" }
                    ]
                },
                {
                    title: "Dock",
                    rows: [
                        { kind: "switch", key: "dock", icon: "", title: "Show dock", subtitle: "App dock at the bottom of the screen" },
                        { kind: "switch", key: "dockautohide", icon: "visibility_off", title: "Hide over open windows", subtitle: "Reveal it from the bottom edge" },
                        { kind: "slider", key: "dockicons", icon: "apps", title: "Dock icon size" }
                    ]
                },
                {
                    title: "",
                    rows: [
                        { kind: "nav", act: "resetcustom", icon: "restart_alt", title: "Restore layout defaults", subtitle: "Reset corners, dock, control center and widget sizes", dangerous: true }
                    ]
                }
            ],
            "widgets": [
                {
                    title: "Desktop widgets",
                    rows: [
                        { kind: "switch", key: "clock", icon: "schedule", title: "Clock widget" },
                        { kind: "switch", key: "clockseconds", icon: "timer", title: "Show seconds" },
                        { kind: "switch", key: "clock24h", icon: "schedule", title: "24-hour time" },
                        { kind: "slider", key: "clocksize", icon: "schedule", title: "Clock size" },
                        { kind: "switch", key: "weather", icon: "partly_cloudy_day", title: "Weather widget" },
                        { kind: "slider", key: "weathersize", icon: "partly_cloudy_day", title: "Weather size" },
                        { kind: "switch", key: "cava", icon: "graphic_eq", title: "Audio wave widget", subtitle: "Visualizes whatever is playing" },
                        { kind: "slider", key: "cavasize", icon: "graphic_eq", title: "Audio wave size" }
                    ]
                }
            ],
            "themes": [
                {
                    title: "Theme",
                    layout: "themes",
                    rows: [
                        { kind: "nav", page: "themes", icon: "", title: "Theme", subtitle: "Color theme for the whole desktop" }
                    ]
                },
                {
                    title: "Wallpaper",
                    layout: "wallpapers",
                    rows: [
                        { kind: "nav", page: "themes", icon: "", title: "Wallpaper", subtitle: "Pick a wallpaper for this theme" }
                    ]
                }
            ],
            "about": [
                {
                    title: "Profile",
                    rows: [
                        { kind: "nav", act: "pfp", icon: "account_circle", title: "Profile picture", subtitle: "Shown here, on the lock screen and at login" },
                        { kind: "nav", act: "pfpreset", icon: "restart_alt", title: "Use the default picture" }
                    ]
                },
                {
                    title: "Device",
                    rows: [
                        { kind: "info", key: "host", icon: "", title: "Device name" },
                        { kind: "info", key: "user", icon: "", title: "User" },
                        { kind: "info", key: "os", icon: "", title: "Operating system" },
                        { kind: "info", key: "kernel", icon: "", title: "Kernel" },
                        { kind: "info", key: "uptime", icon: "", title: "Uptime" }
                    ]
                }
            ]
        })

    function sectionsFor(id) {
        if (id !== "search")
            return pageSections[id] || [];
        var q = query.trim().toLowerCase();
        var hits = [];
        for (var p in pageSections) {
            // The overview only repeats other pages' rows.
            if (p === "overview")
                continue;
            pageSections[p].forEach(sec => sec.rows.forEach(r => {
                if (r.title.toLowerCase().indexOf(q) !== -1 || (r.subtitle || "").toLowerCase().indexOf(q) !== -1)
                    hits.push(Object.assign({}, r, { sub: undefined, subtitle: pageTitles[p] }));
            }));
        }
        return hits.length ? [{ title: "Results", rows: hits }] : [];
    }

    // ── layout ──────────────────────────────────────────────────────
    Item {
        id: card

        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: event => {
            root.back();
            event.accepted = true;
        }
        Keys.onUpPressed: event => {
            root.stepPage(-1);
            event.accepted = true;
        }
        Keys.onDownPressed: event => {
            root.stepPage(1);
            event.accepted = true;
        }

        // The theme's own background, so translucent themes stay translucent
        // here too; Hyprland blurs what's behind (see windowrules.lua), which
        // keeps the text readable.
        Rectangle {
            id: cardBg
            anchors.fill: parent
            // Same panel corner as the shell's notch/island panels; no
            // outline — like the rest of the shell, it separates by tone.
            // Square: Hyprland rounds the window (its decoration rounding).
            radius: 0
            color: Palette.Theme.bg
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 1
            spacing: 0

            // ── left: profile, search, menu ─────────────────────────
            ColumnLayout {
                Layout.preferredWidth: 224
                Layout.maximumWidth: 224
                Layout.fillWidth: false
                Layout.fillHeight: true
                Layout.margins: 14
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    Layout.leftMargin: 6
                    spacing: 10

                    // Click to choose a new picture (scripts/pfp.sh).
                    Avatar {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34

                        scale: avatarMouse.pressed ? 0.9 : 1
                        Behavior on scale {
                            SpatialMotion {
                                fast: true
                                bouncy: true
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: Qt.rgba(0, 0, 0, 0.45)
                            opacity: avatarMouse.containsMouse ? 1 : 0

                            Behavior on opacity {
                                EffectMotion {}
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "edit"
                                color: "white"
                                font.family: Palette.Theme.fontIcons
                                font.weight: Palette.Theme.iconWeight
                                font.pixelSize: Palette.Theme.iconSizeSmall
                            }
                        }

                        MouseArea {
                            id: avatarMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.activate({ act: "pfp" })
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            Layout.fillWidth: true
                            text: root.about.user || Quickshell.env("USER")
                            color: Palette.Theme.textPrimary
                            font.family: Palette.Theme.fontSans
                            font.pixelSize: Palette.Theme.fontSizeBody
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.about.host || ""
                            color: Palette.Theme.textMuted
                            font.family: Palette.Theme.fontSans
                            font.pixelSize: Palette.Theme.fontSizeXs
                            elide: Text.ElideRight
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    radius: Palette.Theme.radiusSmall
                    color: Palette.Theme.surfaceContainerHigh
                    border.width: searchInput.activeFocus ? 1 : 0
                    border.color: Palette.Theme.accent

                    Behavior on radius {
                        SpatialMotion {}
                    }
                    Behavior on border.color {
                        ColorMotion {}
                    }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        text: "search"
                        color: Palette.Theme.textMuted
                        font.family: Palette.Theme.fontIcons
                        font.weight: Palette.Theme.iconWeight
                        font.pixelSize: Palette.Theme.iconSizeSmall
                    }

                    TextInput {
                        id: searchInput
                        anchors.fill: parent
                        anchors.leftMargin: 34
                        anchors.rightMargin: 32
                        verticalAlignment: TextInput.AlignVCenter
                        color: Palette.Theme.textPrimary
                        font.family: Palette.Theme.fontSans
                        font.pixelSize: Palette.Theme.fontSizeSmall
                        selectByMouse: true
                        clip: true
                        onTextChanged: root.query = text

                        Keys.onEscapePressed: event => {
                            root.back();
                            event.accepted = true;
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: searchInput.text === ""
                            text: "Search"
                            color: Palette.Theme.textMuted
                            font: searchInput.font
                        }
                    }

                    IconButton {
                        anchors.right: parent.right
                        anchors.rightMargin: 4
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "close"
                        implicitWidth: 24
                        implicitHeight: 24
                        visible: searchInput.text !== ""
                        onClicked: {
                            searchInput.text = "";
                            searchInput.forceActiveFocus();
                        }
                    }
                }

                // The selection is one tonal pill that glides between
                // entries rather than each entry filling itself in.
                // Scrolls when the entries don't fit (short or tiled windows).
                Flickable {
                    id: navScroll
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: width
                    contentHeight: navColumn.implicitHeight + 8
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    WheelHandler {
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: event => {
                            var delta = event.pixelDelta.y !== 0 ? event.pixelDelta.y * 1.35 : event.angleDelta.y / 120 * 56;
                            navScroll.contentY = Math.max(0, Math.min(navScroll.contentY - delta, navScroll.contentHeight - navScroll.height));
                            event.accepted = true;
                        }
                    }

                    MovingHighlight {
                        target: {
                            if (navRepeater.count === 0)
                                return null;
                            // Like the launcher: follow the hovered entry,
                            // else rest on the open page.
                            for (var h = 0; h < navRepeater.count; h++) {
                                var item = navRepeater.itemAt(h);
                                if (item && item.hovered)
                                    return item;
                            }
                            for (var i = 0; i < root.categories.length; i++) {
                                if (root.categories[i].id === root.activePage)
                                    return navRepeater.itemAt(i);
                            }
                            return null;
                        }
                        radius: Palette.Theme.radiusSmall
                        color: Palette.Theme.accentTonal
                    }

                    Column {
                        id: navColumn
                        width: parent.width
                        spacing: 2

                        Repeater {
                            id: navRepeater
                            model: root.categories

                            delegate: SettingsNavItem {
                                required property var modelData

                                width: parent.width
                                icon: modelData.icon
                                label: modelData.title
                                selected: root.activePage === modelData.id
                                hue: ({
                                        overview: Palette.Theme.accent,
                                        themes: Palette.Theme.purple,
                                        appearance: Palette.Theme.blue,
                                        widgets: Palette.Theme.yellow,
                                        network: Palette.Theme.blue,
                                        display: Palette.Theme.aqua,
                                        sound: Palette.Theme.orange,
                                        power: Palette.Theme.green,
                                        about: Palette.Theme.textSecondary
                                    })[modelData.id] || Palette.Theme.accent
                                onClicked: {
                                    searchInput.text = "";
                                    root.page = modelData.id;
                                }
                            }
                        }
                    }
                }

            }

            // ── right: page header + content ────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: 28
                Layout.rightMargin: 20
                Layout.topMargin: 20
                spacing: 18

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            Layout.fillWidth: true
                            text: root.pageTitles[root.activePage] || ""
                            color: Palette.Theme.textPrimary
                            font.family: Palette.Theme.fontSans
                            font.pixelSize: Palette.Theme.fontSizeHeadline
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.pageSummary(root.activePage)
                            color: Palette.Theme.textMuted
                            font.family: Palette.Theme.fontSans
                            font.pixelSize: Palette.Theme.fontSizeSmall
                            elide: Text.ElideRight
                        }
                    }

                    IconButton {
                        Layout.alignment: Qt.AlignTop
                        icon: "close"
                        implicitWidth: 30
                        implicitHeight: 30
                        onClicked: root.close()
                    }
                }

                Item {
                    id: pages
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.rightMargin: 8
                    clip: true

                    Repeater {
                        model: root.pageIds

                        delegate: SettingsPage {
                            id: pageView

                            required property string modelData

                            readonly property bool current: root.activePage === modelData

                            width: pages.width
                            height: pages.height
                            panel: root
                            sections: root.sectionsFor(modelData)
                            y: current ? 0 : 24
                            opacity: current ? 1 : 0
                            visible: opacity > 0.01
                            enabled: current

                            Behavior on y {
                                SpatialMotion {}
                            }
                            Behavior on opacity {
                                EffectMotion {
                                    fast: false
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: modelData === "search" && pageView.current && pageView.sections.length === 0
                                text: "No settings match “" + root.query + "”"
                                color: Palette.Theme.textMuted
                                font.family: Palette.Theme.fontSans
                                font.pixelSize: Palette.Theme.fontSizeBody
                            }
                        }
                    }
                }
            }
        }
        // Save / Cancel bar for unsaved changes (or a prompt like Reset).
        // Its shape follows the corner roundness setting.
        Rectangle {
            id: notice
            readonly property bool asking: root.promptText !== ""
            readonly property bool unsaved: !asking && root.pendingCount > 0
            readonly property bool shown: root.noticeText !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: shown ? 18 : 4
            width: Math.min(parent.width - 48, noticeRow.implicitWidth + 28)
            height: 48
            radius: Math.min(height / 2, Palette.Theme.radiusLarge)
            color: Palette.Theme.surfaceContainerHigh
            opacity: shown ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                EffectMotion {}
            }
            Behavior on anchors.bottomMargin {
                SpatialMotion {
                    fast: true
                }
            }

            RowLayout {
                id: noticeRow
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 8
                spacing: 10

                Text {
                    text: notice.asking ? "help" : (notice.unsaved ? "edit" : "check_circle")
                    color: Palette.Theme.accent
                    font.family: Palette.Theme.fontIcons
                    font.weight: Palette.Theme.iconWeight
                    font.pixelSize: Palette.Theme.iconSize
                }

                Text {
                    Layout.fillWidth: true
                    text: root.noticeText
                    color: Palette.Theme.textPrimary
                    font.family: Palette.Theme.fontSans
                    font.pixelSize: Palette.Theme.fontSizeSmall
                    elide: Text.ElideRight
                }

                NoticeButton {
                    visible: notice.asking || notice.unsaved
                    label: "Cancel"
                    onClicked: {
                        if (notice.asking)
                            root.promptText = "";
                        else
                            root.cancelPending();
                    }
                }

                NoticeButton {
                    visible: notice.asking || notice.unsaved
                    label: notice.asking ? root.promptAction : "Save"
                    filled: true
                    onClicked: {
                        if (notice.asking) {
                            var callback = root.promptCallback;
                            root.promptText = "";
                            if (callback)
                                callback();
                        } else {
                            root.savePending();
                        }
                    }
                }
            }
        }
    }

    // A notice bar button; its corners follow the roundness setting.
    component NoticeButton: Rectangle {
        id: button
        property string label: ""
        property bool filled: false
        signal clicked

        implicitWidth: buttonText.implicitWidth + 28
        implicitHeight: 32
        radius: Math.min(height / 2, Palette.Theme.radiusSmall)
        color: filled ? Palette.Theme.accent : "transparent"
        scale: buttonMouse.pressed ? 0.94 : 1

        Behavior on scale {
            SpatialMotion {
                fast: true
                bouncy: true
            }
        }

        StateLayer {
            radius: button.radius
            tone: button.filled ? Palette.Theme.accentText : Palette.Theme.textPrimary
            hovered: buttonMouse.containsMouse
            pressed: buttonMouse.pressed
        }

        Text {
            id: buttonText
            anchors.centerIn: parent
            text: button.label
            color: button.filled ? Palette.Theme.accentText : Palette.Theme.textPrimary
            font.family: Palette.Theme.fontSans
            font.pixelSize: Palette.Theme.fontSizeSmall
            font.weight: Font.DemiBold
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }
}
