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

    readonly property real cardWidth: 940
    readonly property real cardHeight: 600

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

    readonly property var tints: [Palette.Theme.accent, Palette.Theme.info, Palette.Theme.success, Palette.Theme.warning, Palette.Theme.secondaryText, Palette.Theme.errorColor, Palette.Theme.primaryText]

    function tintFor(i) {
        return tints[(i || 0) % tints.length];
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
        { id: "overview", icon: "", title: "Overview", sub: "overview", tint: 0 },
        { id: "network", icon: "", title: "Network & internet", sub: "net", tint: 1 },
        { id: "display", icon: "", title: "Display", sub: "display", tint: 3 },
        { id: "sound", icon: "", title: "Sound", sub: "sound", tint: 0 },
        { id: "notifications", icon: "", title: "Notifications", sub: "notifications", tint: 5 },
        { id: "power", icon: "", title: "Battery & power", sub: "power", tint: 2 },
        { id: "appearance", icon: "", title: "Appearance", sub: "appearance", tint: 4 },
        { id: "about", icon: "", title: "About device", sub: "about", tint: 6 }
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
                        { kind: "switch", key: "wifi", icon: "", title: "Wi-Fi", tint: 1 },
                        { kind: "switch", key: "bluetooth", icon: "", title: "Bluetooth", tint: 0 },
                        { kind: "switch", key: "dnd", icon: "", title: "Do not disturb", tint: 5 },
                        { kind: "switch", key: "nightlight", icon: "", title: "Night light", tint: 3 },
                        { kind: "switch", key: "keepawake", icon: "", title: "Keep awake", tint: 2 },
                        { kind: "switch", key: "dock", icon: "", title: "Dock", tint: 4 }
                    ]
                },
                {
                    title: "Levels",
                    rows: [
                        { kind: "slider", key: "brightness", icon: "", title: "Brightness", tint: 3 },
                        { kind: "slider", key: "volume", icon: "", title: "Volume", tint: 0 },
                        { kind: "slider", key: "mic", icon: "", title: "Microphone", tint: 1 }
                    ]
                }
            ],
            "network": [
                {
                    title: "Connections",
                    rows: [
                        { kind: "switch", key: "wifi", icon: "", title: "Wi-Fi", tint: 1 },
                        { kind: "switch", key: "bluetooth", icon: "", title: "Bluetooth", tint: 0 },
                        { kind: "switch", key: "airplane", icon: "", title: "Airplane mode", subtitle: "Turns off Wi-Fi and Bluetooth", tint: 5 }
                    ]
                }
            ],
            "display": [
                {
                    title: "Brightness",
                    rows: [
                        { kind: "slider", key: "brightness", icon: "", title: "Brightness level", tint: 3 },
                        { kind: "switch", key: "nightlight", icon: "", title: "Night light", subtitle: "Warmer colors at night", tint: 3 }
                    ]
                }
            ],
            "sound": [
                {
                    title: "Volume",
                    rows: [
                        { kind: "slider", key: "volume", icon: "", title: "Media volume", tint: 0 },
                        { kind: "switch", key: "mute", icon: "", title: "Mute", tint: 0 }
                    ]
                },
                {
                    title: "Microphone",
                    rows: [
                        { kind: "slider", key: "mic", icon: "", title: "Microphone level", tint: 1 },
                        { kind: "switch", key: "micmute", icon: "", title: "Mute microphone", tint: 1 }
                    ]
                },
                {
                    title: "",
                    rows: [
                        { kind: "nav", act: "mixer", icon: "", title: "Audio mixer", subtitle: "Open per-app volume controls", tint: 4 }
                    ]
                }
            ],
            "notifications": [
                {
                    title: "",
                    rows: [
                        { kind: "switch", key: "dnd", icon: "", title: "Do not disturb", subtitle: "Silence notification popups", tint: 5 },
                        { kind: "nav", act: "clearnotifs", icon: "", title: "Clear all notifications", tint: 5 }
                    ]
                }
            ],
            "power": [
                {
                    title: "Power mode",
                    rows: [
                        {
                            kind: "segment", key: "powerprofile", title: "Performance profile", tint: 2,
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
                        { kind: "info", key: "battery", icon: "", title: "Battery level", tint: 2 },
                        { kind: "switch", key: "keepawake", icon: "", title: "Keep screen awake", subtitle: "Prevent the screen from locking or sleeping", tint: 3 }
                    ]
                }
            ],
            "appearance": [
                {
                    title: "Style",
                    rows: [
                        { kind: "nav", open: "theme", icon: "", title: "Theme", sub: "appearance", tint: 4 },
                        { kind: "nav", open: "wallpaper", icon: "", title: "Wallpaper", subtitle: "Pick a wallpaper for this theme", tint: 1 },
                        { kind: "nav", open: "barlayout", icon: "", title: "Bar position", subtitle: "Move the bar between the top and the side", tint: 3 }
                    ]
                },
                {
                    title: "Desktop widgets",
                    rows: [
                        { kind: "switch", key: "dock", icon: "", title: "Dock", subtitle: "App dock at the bottom of the screen", tint: 0 },
                        { kind: "switch", key: "clock", icon: "", title: "Clock widget", tint: 2 },
                        { kind: "switch", key: "weather", icon: "", title: "Weather widget", tint: 1 }
                    ]
                }
            ],
            "about": [
                {
                    title: "Device",
                    rows: [
                        { kind: "info", key: "host", icon: "", title: "Device name", tint: 6 },
                        { kind: "info", key: "user", icon: "", title: "User", tint: 6 },
                        { kind: "info", key: "os", icon: "", title: "Operating system", tint: 6 },
                        { kind: "info", key: "kernel", icon: "", title: "Kernel", tint: 6 },
                        { kind: "info", key: "uptime", icon: "", title: "Uptime", tint: 6 }
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

        Rectangle {
            id: cardBg
            anchors.fill: parent
            radius: 34
            color: Palette.Theme.surface
            border.width: 1
            border.color: Palette.Theme.outlineVariant
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            // ── left: profile, search, menu ─────────────────────────
            Rectangle {
                Layout.preferredWidth: 252
                Layout.fillHeight: true
                radius: 26
                color: Palette.Theme.surfaceContainer

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        spacing: 12

                        Rectangle {
                            Layout.preferredWidth: 52
                            Layout.preferredHeight: 52
                            radius: 26
                            color: Palette.Theme.surfaceContainerHighest
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
                                font.pixelSize: 16
                                font.weight: Font.Bold
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: root.about.host || ""
                                color: Palette.Theme.textMuted
                                font.family: Palette.Theme.fontSans
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        radius: 22
                        color: Palette.Theme.surfaceContainerHigh
                        border.width: searchInput.activeFocus ? 1.5 : 0
                        border.color: Palette.Theme.accent

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 14
                            anchors.verticalCenter: parent.verticalCenter
                            text: ""
                            color: Palette.Theme.textMuted
                            font.family: Palette.Theme.fontIcons
                            font.pixelSize: 20
                        }

                        TextInput {
                            id: searchInput
                            anchors.fill: parent
                            anchors.leftMargin: 44
                            anchors.rightMargin: 40
                            verticalAlignment: TextInput.AlignVCenter
                            color: Palette.Theme.textPrimary
                            font.family: Palette.Theme.fontSans
                            font.pixelSize: 13
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
                                text: "Search settings"
                                color: Palette.Theme.textMuted
                                font: searchInput.font
                            }
                        }

                        IconButton {
                            anchors.right: parent.right
                            anchors.rightMargin: 7
                            anchors.verticalCenter: parent.verticalCenter
                            icon: ""
                            implicitWidth: 28
                            implicitHeight: 28
                            visible: searchInput.text !== ""
                            onClicked: {
                                searchInput.text = "";
                                searchInput.forceActiveFocus();
                            }
                        }
                    }

                    Column {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        spacing: 4

                        Repeater {
                            model: root.categories

                            delegate: SettingsNavItem {
                                required property var modelData

                                width: parent.width
                                icon: modelData.icon
                                label: modelData.title
                                tint: root.tintFor(modelData.tint)
                                selected: root.activePage === modelData.id
                                onClicked: {
                                    searchInput.text = "";
                                    root.page = modelData.id;
                                }
                            }
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }
                }
            }

            // ── right: page header + dashboard ──────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.leftMargin: 10
                Layout.rightMargin: 12
                Layout.topMargin: 10
                Layout.bottomMargin: 6
                spacing: 14

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
                            font.pixelSize: 28
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.pageSummary(root.activePage)
                            color: Palette.Theme.textMuted
                            font.family: Palette.Theme.fontSans
                            font.pixelSize: 13
                            elide: Text.ElideRight
                        }
                    }

                    IconButton {
                        Layout.alignment: Qt.AlignTop
                        icon: ""
                        implicitWidth: 38
                        implicitHeight: 38
                        onClicked: root.close()
                    }
                }

                Item {
                    id: pages
                    Layout.fillWidth: true
                    Layout.fillHeight: true
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
                            y: current ? 0 : 16
                            opacity: current ? 1 : 0
                            visible: opacity > 0.01
                            enabled: current

                            Behavior on y {
                                NumberAnimation {
                                    duration: 260
                                    easing.type: Easing.OutCubic
                                }
                            }
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 200
                                }
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: modelData === "search" && pageView.current && pageView.sections.length === 0
                                text: "No settings match “" + root.query + "”"
                                color: Palette.Theme.textMuted
                                font.family: Palette.Theme.fontSans
                                font.pixelSize: 14
                            }
                        }
                    }
                }
            }
        }
    }
}
