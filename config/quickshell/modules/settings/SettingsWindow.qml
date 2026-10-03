pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../components/material"
import "../../theme" as Palette

// System settings as an ordinary floating window (a real toplevel, so it
// stacks, focuses and closes like any app and never sits over the bar): a
// menu on the left, the selected page's dashboard on the right. The window
// rule in hypr/modules/windowrules.lua makes it float, centered. It hosts no
// logic of its own for volume, brightness, network etc. — it drives the
// control center's existing, tested handlers.
FloatingWindow {
    id: root

    property var controlCenter: null
    property var widgetsService: null
    property var themeService: null

    property string page: "overview"
    property string query: ""

    readonly property string activePage: query.trim() !== "" ? "search" : page

    property bool shown: false

    signal aboutToOpen
    // Ask the shell to open one of the overlay pickers ("theme", "wallpaper", "barlayout").
    signal requestOpen(string what)

    readonly property real cardWidth: 860
    readonly property real cardHeight: 560

    // Matched by the Hyprland window rule.
    title: "nixcraft-settings"
    visible: shown
    color: "transparent"
    implicitWidth: cardWidth
    implicitHeight: cardHeight
    minimumSize: Qt.size(cardWidth, cardHeight)
    maximumSize: Qt.size(cardWidth, cardHeight)

    // The window can also be closed by the compositor (e.g. SUPER+Q).
    onVisibleChanged: {
        if (!visible)
            shown = false;
    }

    // So summaries (also shown by the launcher's /settings list) are filled
    // in before the window is ever opened.
    Component.onCompleted: aboutProcess.running = true

    readonly property var pageIds: ["overview", "network", "display", "sound", "notifications", "power", "appearance", "about", "search"]

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
        if (controlCenter)
            controlCenter.refreshAll();
        aboutProcess.running = true;
        searchInput.forceActiveFocus();
    }

    function openPage(name) {
        open();
        if (pageIds.indexOf(name) !== -1 && name !== "search")
            page = name;
    }

    function close() {
        shown = false;
        searchInput.text = "";
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
        default:
            return false;
        }
    }

    function setFlag(key, on) {
        var c = controlCenter;
        if (flag(key) === on)
            return;
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
        }
    }

    function level(key) {
        var c = controlCenter;
        if (!c)
            return 0;
        switch (key) {
        case "volume":
            return c.volumeValue;
        case "brightness":
            return c.brightnessValue;
        case "mic":
            return c.micValue;
        default:
            return 0;
        }
    }

    function setLevel(key, value) {
        var c = controlCenter;
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
        }
    }

    function choice(key) {
        return key === "powerprofile" && controlCenter ? controlCenter.powerProfile : "";
    }

    function setChoice(key, id) {
        if (key === "powerprofile" && controlCenter)
            controlCenter.setPowerProfile(id);
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
        case "net":
            return "Wi-Fi " + (flag("wifi") ? "on" : "off") + "  ·  Bluetooth " + (flag("bluetooth") ? "on" : "off");
        case "display":
            return "Brightness " + pct(level("brightness")) + (flag("nightlight") ? "  ·  Night light on" : "");
        case "sound":
            return flag("mute") ? "Muted" : "Volume " + pct(level("volume"));
        case "notifications":
            return flag("dnd") ? "Do not disturb is on" : (c ? c.notificationCount + " new" : "");
        case "power":
            return (batteryPercent >= 0 ? batteryPercent + "%" + (batteryCharging ? " charging" : "") + "  ·  " : "") + (profileNames[choice("powerprofile")] || "");
        case "appearance":
            return themeService && themeService.activeTheme ? "Theme: " + themeService.activeTheme : "Theme, wallpaper, dock";
        case "about":
            return about.host || "This device";
        default:
            return "";
        }
    }

    property var about: ({})

    function infoFor(key) {
        switch (key) {
        case "battery":
            return batteryPercent >= 0 ? batteryPercent + "%" + (batteryCharging ? " · charging" : "") : "No battery";
        default:
            return about[key] || "…";
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
        if (spec.open) {
            // Hand keyboard focus over: close first, then let the shell open the picker.
            close();
            requestOpen(spec.open);
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
        { id: "network", icon: "", title: "Network & internet", sub: "net" },
        { id: "display", icon: "", title: "Display", sub: "display" },
        { id: "sound", icon: "", title: "Sound", sub: "sound" },
        { id: "notifications", icon: "", title: "Notifications", sub: "notifications" },
        { id: "power", icon: "", title: "Battery & power", sub: "power" },
        { id: "appearance", icon: "", title: "Appearance", sub: "appearance" },
        { id: "about", icon: "", title: "About device", sub: "about" }
    ]

    readonly property var pageTitles: ({
            "overview": "Overview",
            "network": "Network & internet",
            "display": "Display",
            "sound": "Sound",
            "notifications": "Notifications",
            "power": "Battery & power",
            "appearance": "Appearance",
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
                        { kind: "switch", key: "nightlight", icon: "", title: "Night light", subtitle: "Warmer colors at night" }
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
            "notifications": [
                {
                    title: "",
                    rows: [
                        { kind: "switch", key: "dnd", icon: "", title: "Do not disturb", subtitle: "Silence notification popups" },
                        { kind: "nav", act: "clearnotifs", icon: "", title: "Clear all notifications" }
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
                }
            ],
            "appearance": [
                {
                    title: "Style",
                    rows: [
                        { kind: "nav", open: "theme", icon: "", title: "Theme", sub: "appearance" },
                        { kind: "nav", open: "wallpaper", icon: "", title: "Wallpaper", subtitle: "Pick a wallpaper for this theme" },
                        { kind: "nav", open: "barlayout", icon: "", title: "Bar position", subtitle: "Move the bar between the top and the side" }
                    ]
                },
                {
                    title: "Desktop widgets",
                    rows: [
                        { kind: "switch", key: "dock", icon: "", title: "Dock", subtitle: "App dock at the bottom of the screen" },
                        { kind: "switch", key: "clock", icon: "", title: "Clock widget" },
                        { kind: "switch", key: "weather", icon: "", title: "Weather widget" },
                        { kind: "switch", key: "cava", icon: "graphic_eq", title: "Audio wave widget", subtitle: "Visualizes whatever is playing" }
                    ]
                }
            ],
            "about": [
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

        // Always opaque, even under translucent themes, so whatever is
        // behind the window never bleeds through the text.
        Rectangle {
            id: cardBg
            anchors.fill: parent
            radius: Palette.Theme.radiusExtraLarge
            color: Palette.Theme.surfaceSolid
            border.width: 1
            border.color: Palette.Theme.outlineSoft
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

                    Rectangle {
                        Layout.preferredWidth: 34
                        Layout.preferredHeight: 34
                        radius: 17
                        color: Palette.Theme.surfaceContainerHigh
                        clip: true

                        Image {
                            anchors.fill: parent
                            source: "file://" + Quickshell.env("HOME") + "/Pictures/misc/pfp.png"
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            smooth: true
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
                    radius: searchInput.activeFocus ? height / 2 : Palette.Theme.radiusSmall
                    color: Palette.Theme.surfaceContainer
                    border.width: 1
                    border.color: searchInput.activeFocus ? Palette.Theme.accent : Palette.Theme.outlineSoft

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
                Item {
                    Layout.fillWidth: true
                    implicitHeight: navColumn.implicitHeight

                    MovingHighlight {
                        target: {
                            if (navRepeater.count === 0)
                                return null;
                            for (var i = 0; i < root.categories.length; i++) {
                                if (root.categories[i].id === root.activePage)
                                    return navRepeater.itemAt(i);
                            }
                            return null;
                        }
                        radius: height / 2
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
                                onClicked: {
                                    searchInput.text = "";
                                    root.page = modelData.id;
                                }
                            }
                        }
                    }
                }

                Item {
                    Layout.fillHeight: true
                }
            }

            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                color: Palette.Theme.outlineSoft
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
    }
}
