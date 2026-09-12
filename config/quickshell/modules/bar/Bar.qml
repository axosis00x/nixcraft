import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import Quickshell.Widgets
import "../../components/material"
import "../../config/Ui.js" as Ui
import "../../theme" as Palette

PanelWindow {
    id: bar

    // Horizontal strip along the top edge (default) or a vertical dock along
    // the left edge — backed by services/BarLayoutService.qml, toggled live
    // via `quickshell ipc call bar toggle` (bound to SUPER+SHIFT+B).
    property var barLayout: null
    readonly property bool vertical: barLayout ? barLayout.vertical : false

    anchors {
        top: true
        left: true
        right: !bar.vertical
        bottom: bar.vertical
    }
    margins {
        top: 0
        right: 0
        left: 0
        bottom: 0
    }
    // Only the dimension that isn't pinned down by anchors on both sides
    // actually applies: implicitHeight governs thickness in horizontal mode,
    // implicitWidth governs thickness in vertical mode.
    implicitHeight: 34
    implicitWidth: Ui.barThickness
    color: "transparent"

    property string centerMode: "normal"
    // Scroll-cycled content shown in the center notch. "apps" (active
    // window name) is the default; scrolling the notch steps through
    // the rest.
    property var centerModules: ["apps", "clock", "cava"]
    property int centerModuleIndex: 0
    // Remembers what was showing before playback auto-switched to cava,
    // so stopping playback restores it instead of always falling back to apps.
    property int previousCenterModuleIndex: 0
    property bool isRecording: false
    property var launcher: null
    property var controlCenter: null
    property var powerMenu: null
    property var themePicker: null
    property var clipboard: null
    property var mediaPanel: null
    property var toolMenu: null
    property var emojiPicker: null
    property var workspacesService: null
    property var ensureControlCenter: null
    property real osdValue: 0
    property string osdLabel: "0%"
    property var osd: null

    // Exposed so CenterOverlay can seed its stage from the bar notch's
    // current collapsed width, creating a seamless expand transition.
    readonly property real centerCapsuleSlabWidth: centerCapsule ? centerCapsule.slabWidth : 120

    readonly property real minLevel: 0.05

    property real currentVolume: 0.5
    property real currentBrightness: 0.5
    property bool currentVolumeMuted: false
    property bool suppressVolumeOsd: false
    property bool suppressBrightnessOsd: false
    property string appClass: ""
    property string appTitle: "Desktop"

    property var player: {
        var list = Mpris.players.values;
        if (list.length === 0)
            return null;
        for (var i = 0; i < list.length; i++) {
            if (list[i].playbackState === MprisPlaybackState.Playing)
                return list[i];
        }
        return list[0];
    }

    property bool mediaPlaying: {
        var list = Mpris.players.values;
        for (var i = 0; i < list.length; i++) {
            if (list[i].playbackState === MprisPlaybackState.Playing)
                return true;
        }
        return false;
    }

    // Auto-switch the notch to the cava visualizer when playback starts,
    // and restore whatever module was showing before once it stops.
    onMediaPlayingChanged: {
        var cavaIdx = centerModules.indexOf("cava");
        if (cavaIdx < 0)
            return;
        if (mediaPlaying) {
            if (centerModuleIndex !== cavaIdx) {
                previousCenterModuleIndex = centerModuleIndex;
                centerModuleIndex = cavaIdx;
            }
        } else if (centerModuleIndex === cavaIdx) {
            centerModuleIndex = previousCenterModuleIndex;
        }
    }

    property int batteryPercent: 0
    property bool batteryCharging: false
    property bool batteryAvailable: false

    function checkRecording() {
        recordingCheck.exec(["pgrep", "-x", "wf-recorder"]);
    }

    Process {
        id: recordingCheck
        onExited: (exitCode) => {
            bar.isRecording = (exitCode === 0);
        }
    }

    Timer {
        id: recordingTimer
        interval: 3000
        running: true
        repeat: true
        onTriggered: bar.checkRecording()
    }

    Component.onCompleted: {
        readVolume(true);
        readBrightness(true);
        readBattery();
        checkRecording();
    }

    function showOsd(kind, value, label) {
        osdValue = Math.max(0, Math.min(1, value));
        osdLabel = label !== undefined ? label : (Math.round(osdValue * 100) + "%");
        if (osd)
            osd.showMeter(kind, osdValue, osdLabel);
    }

    function showLockOsd(kind, enabled) {
        if (osd)
            osd.showLock(kind, enabled);
    }

    function syncControlCenterVolume() {
        var panel = getControlCenter(false);
        if (panel && typeof panel.syncVolumeFromBar === "function")
            panel.syncVolumeFromBar(currentVolume, currentVolumeMuted);
    }

    function syncControlCenterBrightness() {
        var panel = getControlCenter(false);
        if (panel && typeof panel.syncBrightnessFromBar === "function")
            panel.syncBrightnessFromBar(currentBrightness);
    }

    function syncVolumeFromControlCenter(value, muted, show) {
        currentVolume = Math.max(0, Math.min(1, value));
        currentVolumeMuted = muted;
        if (show)
            showOsd("volume", currentVolume, muted ? "Muted" : undefined);
    }

    function syncBrightnessFromControlCenter(value, show) {
        currentBrightness = Math.max(0, Math.min(1, value));
        if (show)
            showOsd("brightness", currentBrightness);
    }

    function parseVolume(data) {
        var match = data.match(/Volume:\s+([0-9.]+)/);
        if (!match || match.length < 2)
            return;
        var volume = Number(match[1]);
        if (isNaN(volume))
            return;
        currentVolume = volume;
        currentVolumeMuted = /MUTED/.test(data);
        syncControlCenterVolume();
        if (!suppressVolumeOsd)
            showOsd("volume", volume, currentVolumeMuted ? "Muted" : undefined);
        suppressVolumeOsd = false;
    }

    function adjustVolume(delta) {
        var target = Math.max(minLevel, Math.min(1, currentVolume + delta));
        volumeAction.exec(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", Math.round(target * 100) + "%"]);
    }

    function toggleMute() {
        volumeAction.exec(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
    }

    function readVolume(silent) {
        if (silent)
            suppressVolumeOsd = true;
        volumeRead.exec(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]);
    }

    function parseBrightness(data) {
        var parts = data.trim().split(",");
        if (parts.length < 5)
            return;
        var percent = Number(parts[3].replace("%", ""));
        if (isNaN(percent))
            return;
        currentBrightness = percent / 100;
        syncControlCenterBrightness();
        if (!suppressBrightnessOsd)
            showOsd("brightness", currentBrightness);
        suppressBrightnessOsd = false;
    }

    function readBrightness(silent) {
        if (silent)
            suppressBrightnessOsd = true;
        brightnessRead.exec(["brightnessctl", "-m"]);
    }

    function adjustBrightness(up) {
        var target = Math.max(minLevel, Math.min(1, currentBrightness + (up ? 0.05 : -0.05)));
        brightnessSet.exec(["brightnessctl", "set", Math.round(target * 100) + "%"]);
    }

    function readBattery() {
        batteryRead.exec(["sh", "-c", "cat /sys/class/power_supply/BAT*/capacity 2>/dev/null || echo ''"]);
    }

    function readBatteryStatus() {
        batteryStatusRead.exec(["sh", "-c", "cat /sys/class/power_supply/BAT*/status 2>/dev/null || echo 'None'"]);
    }

    // Window classes don't always match their icon theme name (e.g. Zed
    // reports "dev.zed.Zed" but ships an icon literally named "zed") —
    // resolve through the desktop entry first, falling back to a direct
    // lookup for the common case where they already match.
    property var iconCache: ({})
    function iconForClass(cls) {
        if (!cls)
            return "";
        if (iconCache[cls] !== undefined)
            return iconCache[cls];
        var entry = DesktopEntries.heuristicLookup(cls);
        var res = "";
        if (entry && entry.icon)
            res = Quickshell.iconPath(entry.icon, true);
        else
            res = Quickshell.iconPath(cls, true);
        iconCache[cls] = res;
        return res;
    }

    function getControlCenter(create) {
        if (create && typeof ensureControlCenter === "function")
            return ensureControlCenter();
        return controlCenter;
    }

    function toggleControlCenter() {
        var panel = getControlCenter(true);
        if (panel)
            panel.toggleControlCenter();
    }

    function closeControlCenter(immediate) {
        var panel = getControlCenter(false);
        if (panel && panel.visible)
            panel.closeControlCenter(immediate);
    }

    function openLauncher() {
        if (launcher)
            launcher.openLauncher();
    }

    function closeLauncher(immediate) {
        if (launcher && launcher.visible)
            launcher.closeLauncher(immediate);
    }

    function toggleLauncher() {
        if (!launcher)
            return;
        if (launcher.visible)
            launcher.closeLauncher();
        else
            launcher.openLauncher();
    }

    IpcHandler {
        target: "osd"

        function volume(value: real): void {
            bar.syncVolumeFromControlCenter(value > 1 ? value / 100 : value, bar.currentVolumeMuted, true);
            bar.syncControlCenterVolume();
        }
        function brightness(value: real): void {
            bar.syncBrightnessFromControlCenter(value > 1 ? value / 100 : value, true);
            bar.syncControlCenterBrightness();
        }
        function lockState(kind: string, enabled: string): void {
            // The Hyprland keybind reports the state before the lock key is
            // applied, so invert it to show the resulting keyboard state.
            bar.showLockOsd(kind, !(enabled === "1" || String(enabled).toLowerCase() === "true"));
        }
        function volumeUp(): void {
            bar.adjustVolume(0.05);
        }
        function volumeDown(): void {
            bar.adjustVolume(-0.05);
        }
        function mute(): void {
            bar.toggleMute();
        }
        function brightnessUp(): void {
            bar.adjustBrightness(true);
        }
        function brightnessDown(): void {
            bar.adjustBrightness(false);
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "activewindow")
                return;
            var idx = event.data.indexOf(",");
            if (idx <= 0) {
                bar.appClass = "";
                bar.appTitle = "Desktop";
            } else {
                bar.appClass = event.data.substring(0, idx);
                bar.appTitle = event.data.substring(idx + 1);
            }
        }
    }

    Process {
        id: brightnessSet
        command: ["brightnessctl", "set", "+5%"]
        onExited: bar.readBrightness()
    }

    Process {
        id: volumeAction
        onExited: bar.readVolume()
    }

    Process {
        id: volumeRead
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => bar.parseVolume(data)
        }
    }

    Process {
        id: brightnessRead
        command: ["brightnessctl", "-m"]

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => bar.parseBrightness(data)
        }
    }

    Process {
        id: batteryRead
        command: ["sh", "-c", "cat /sys/class/power_supply/BAT*/capacity 2>/dev/null || echo ''"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                var pct = parseInt(data.trim());
                if (!isNaN(pct)) {
                    bar.batteryAvailable = true;
                    bar.batteryPercent = pct;
                }
            }
        }
        onExited: {
            if (bar.batteryAvailable)
                bar.readBatteryStatus();
        }
    }

    Process {
        id: batteryStatusRead
        command: ["sh", "-c", "cat /sys/class/power_supply/BAT*/status 2>/dev/null || echo 'None'"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => bar.batteryCharging = data.trim() === "Charging"
        }
    }

    // Fallback poll — instant updates now come from powerSupplyWatcher below,
    // this just guards against missed/coalesced udev events.
    Timer {
        id: batteryTimer
        interval: 60000
        running: true
        repeat: true
        onTriggered: bar.readBattery()
    }

    // Instant refresh: fires the moment AC is plugged/unplugged or the
    // battery status changes, instead of waiting on the poll interval.
    // Requires `udev` / `systemd` (udevadm) — present by default on NixOS.
    Process {
        id: powerSupplyWatcher
        command: ["udevadm", "monitor", "--udev", "--subsystem-match=power_supply"]
        running: true
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => bar.readBattery()
        }
    }

    Item {
        id: barRow
        visible: !bar.vertical
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            topMargin: 4
        }
        height: 30

        LauncherIsland {
            id: launcherIsland
            anchors.left: parent.left
            anchors.leftMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            bar: bar
        }

        BarSection {
            id: workspacesCapsule
            anchors.left: launcherIsland.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: Math.max(workspaces.implicitWidth + 24, 185)

            MouseArea {
                // The dots no longer have their own click handlers, so this
                // single MouseArea catches every click in the capsule —
                // circles, pills, and empty space alike — and opens the
                // full overview.
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (bar.workspacesService)
                        bar.workspacesService.step(1);
                }
            }

            Workspaces {
                id: workspaces
                anchors.centerIn: parent
                service: bar.workspacesService
            }
        }

        BarSection {
            id: weatherCapsule
            anchors.left: workspacesCapsule.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: weather.implicitWidth + 24
            visible: !bar.vertical && weather.available
        }

        BarSection {
            id: batteryCapsule
            anchors.right: rightCapsule.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: batteryContent.implicitWidth + 24
            visible: bar.batteryAvailable

            Battery {
                id: batteryContent
                anchors.centerIn: parent
                bar: bar
            }
        }

        BarSection {
            id: rightCapsule
            anchors.right: powerCapsule.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: rightRow.implicitWidth + 14

            RowLayout {
                id: rightRow
                anchors.centerIn: parent
                spacing: 8

                Tray {
                    parentWindow: bar
                }

                Divider {
                    vertical: true
                    color: Palette.Theme.textMuted
                    opacity: 0.85
                    Layout.alignment: Qt.AlignVCenter
                }

                IconButton {
                    icon: "\ue1bd"
                    implicitWidth: 26
                    implicitHeight: 34
                    Layout.alignment: Qt.AlignVCenter
                    onClicked: {
                        if (bar.toolMenu && typeof bar.toolMenu.toggleToolMenu === "function")
                            bar.toolMenu.toggleToolMenu();
                    }
                }
            }
        }

        BarSection {
            id: powerCapsule
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: 30
            implicitHeight: 30
            radius: 10

            Text {
                anchors.centerIn: parent
                text: "\ue8ac"
                color: Palette.Theme.textPrimary
                font.family: Palette.Theme.fontIcons
                font.pixelSize: 18
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (bar.powerMenu && typeof bar.powerMenu.togglePowerMenu === "function")
                        bar.powerMenu.togglePowerMenu();
                }
            }
        }
    }

    // Vertical dock layout: launcher + workspaces pinned to the top, a
    // static clock/app-icon/cava stack centered in the middle, and
    // tray/battery/tools/power stacked upward from the bottom. There is no
    // center notch here — popups grow from CenterOverlay's shared stage
    // instead (top-anchored for control center/power/tools, bottom-anchored
    // for everything else — see services/BarLayoutService.qml).
    Item {
        id: barColumn
        visible: bar.vertical
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            topMargin: 4
            // Mirrors barRow's topMargin: 4 above — the same small reveal
            // gap, just rotated onto the leading (left) edge instead of the
            // top one.
            leftMargin: 4
            rightMargin: 0
            bottomMargin: 4
        }

        LauncherIsland {
            id: launcherIslandV
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            implicitWidth: parent.width
            bar: bar
        }

        BarSection {
            id: workspacesCapsuleV
            anchors.top: launcherIslandV.bottom
            anchors.topMargin: 10
            anchors.horizontalCenter: parent.horizontalCenter
            // Every vertical-bar capsule spans the bar's full width so the
            // stack reads as one consistent column instead of a jumble of
            // differently-sized pills.
            implicitWidth: parent.width
            implicitHeight: Math.max(workspacesV.implicitHeight + 24, 155)

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (bar.workspacesService)
                        bar.workspacesService.step(1);
                }
            }

            Workspaces {
                id: workspacesV
                vertical: true
                anchors.centerIn: parent
                service: bar.workspacesService
            }
        }

        // Static vertical stand-in for the horizontal notch's scroll-cycled
        // clock/apps/cava — there's no room to cycle in a narrow column, so
        // all three sit stacked together, always visible, centered in the
        // bar.
        BarSection {
            id: middleCapsuleV
            anchors.verticalCenter: parent.verticalCenter
            anchors.horizontalCenter: parent.horizontalCenter
            implicitWidth: parent.width
            implicitHeight: middleColumnV.implicitHeight + 20

            ColumnLayout {
                id: middleColumnV
                anchors.centerIn: parent
                spacing: 12

                Clock {
                    stacked: true
                    Layout.alignment: Qt.AlignHCenter
                }

                // The "desktop icon shower" — the focused window's icon, or
                // a bare desktop glyph when nothing is focused. Same data
                // the horizontal notch's "apps" module shows.
                Item {
                    id: appIconV
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 18
                    implicitHeight: 18

                    IconImage {
                        anchors.centerIn: parent
                        implicitSize: 16
                        source: bar.iconForClass(bar.appClass)
                        visible: bar.appClass !== "" && source !== ""
                        smooth: true
                        mipmap: true
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "~"
                        visible: bar.appClass === ""
                        color: Palette.Theme.textPrimary
                        font.family: Palette.Theme.fontMono
                        font.pixelSize: 12
                        font.weight: Font.DemiBold
                    }
                }

                // Cava.qml always paints its bars left-to-right (varying in
                // height); rotating the whole visualizer 90° turns that into
                // bars stacked top-to-bottom (varying in width), which is
                // what actually fits a narrow vertical bar. The wrapper Item
                // reports the *post-rotation* footprint to the layout, while
                // the Cava inside it keeps its natural landscape size and
                // just spins in place — avoids overflowing its layout cell.
                Item {
                    id: cavaWrapV
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 14
                    implicitHeight: 24
                    visible: bar.mediaPlaying

                    Cava {
                        id: cavaVisualizerV
                        anchors.centerIn: parent
                        implicitWidth: 24
                        implicitHeight: 14
                        rotation: 90
                        barCount: 3
                        // Mirrors the horizontal notch's cava gating (see
                        // cavaVisualizer above) so only whichever bar is
                        // actually showing keeps a cava process running.
                        active: bar.mediaPlaying && bar.vertical
                    }
                }
            }
        }

        BarSection {
            id: powerCapsuleV
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            implicitWidth: parent.width
            implicitHeight: 30
            radius: 10

            Text {
                anchors.centerIn: parent
                text: ""
                color: Palette.Theme.textPrimary
                font.family: Palette.Theme.fontIcons
                font.pixelSize: 18
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (bar.powerMenu && typeof bar.powerMenu.togglePowerMenu === "function")
                        bar.powerMenu.togglePowerMenu();
                }
            }
        }

        BarSection {
            id: toolCapsuleV
            anchors.bottom: powerCapsuleV.top
            anchors.bottomMargin: 10
            anchors.horizontalCenter: parent.horizontalCenter
            implicitWidth: parent.width
            implicitHeight: toolColumnV.implicitHeight + 14

            ColumnLayout {
                id: toolColumnV
                anchors.centerIn: parent
                spacing: 8

                Tray {
                    parentWindow: bar
                    vertical: true
                    Layout.alignment: Qt.AlignHCenter
                }

                Divider {
                    Layout.preferredWidth: 20
                    Layout.alignment: Qt.AlignHCenter
                    color: Palette.Theme.textMuted
                    opacity: 0.85
                }

                IconButton {
                    icon: ""
                    implicitWidth: 26
                    implicitHeight: 26
                    Layout.alignment: Qt.AlignHCenter
                    onClicked: {
                        if (bar.toolMenu && typeof bar.toolMenu.toggleToolMenu === "function")
                            bar.toolMenu.toggleToolMenu();
                    }
                }
            }
        }

        BarSection {
            id: batteryCapsuleV
            anchors.bottom: toolCapsuleV.top
            anchors.bottomMargin: 10
            anchors.horizontalCenter: parent.horizontalCenter
            implicitWidth: parent.width
            implicitHeight: batteryContentV.implicitHeight + 24
            visible: bar.batteryAvailable

            Battery {
                id: batteryContentV
                vertical: true
                showPercent: false
                anchors.centerIn: parent
                bar: bar
            }
        }

    }

    Weather {
        id: weather
        parent: weatherCapsule
        vertical: false
        anchors.centerIn: parent
    }

    Notch {
        id: centerCapsule
        visible: !bar.vertical
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        slabWidth: centerContentWidth + 24
        slabRadius: 13
        wingSize: 9
        clipContent: false

        readonly property string activeCenterModule: bar.centerModules[bar.centerModuleIndex]

        // "~" and the clock share this width so the notch doesn't resize
        // when cycling between them — cava sizes itself independently, and
        // a real app title (which varies) grows/shrinks the notch too.
        readonly property real idleContentWidth: Math.max(desktopContent.implicitWidth, clockContent.implicitWidth)

        readonly property real centerContentWidth: {
            switch (centerCapsule.activeCenterModule) {
            case "cava":
                return cavaContent.implicitWidth;
            case "clock":
                return centerCapsule.idleContentWidth;
            default:
                return bar.appClass !== "" ? appsContent.implicitWidth : centerCapsule.idleContentWidth;
            }
        }

        // Sits flush against the screen edge (no top gap) while the rest of the
        // bar keeps its small top margin — so matching barRow's *height* would
        // leave the notch's bottom edge sitting above barRow's (whose top
        // margin eats into the same window height). Matching the window's
        // height instead lines up both bottom edges flush with each other,
        // giving the notch and barRow an equal (zero) bottom gap even though
        // their top offsets differ. Grows down out of the edge with a gentle
        // overshoot the first time the shell starts; animating the height
        // rather than sliding the whole notch down keeps the wings welded to
        // the edge for the entire drop.
        readonly property real restHeight: bar.height
        slabHeight: 0

        Component.onCompleted: dropInAnim.start()

        NumberAnimation {
            id: dropInAnim
            target: centerCapsule
            property: "slabHeight"
            to: centerCapsule.restHeight
            duration: 480
            easing.type: Easing.OutBack
            // Kept modest so the bounce peak stays inside the window's height.
            easing.overshoot: 1.0
        }

        Behavior on slabWidth {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
        }

        RowLayout {
            id: appsContent
            anchors.centerIn: parent
            spacing: 7
            // Only mounted once there's an actual app — no hidden icon
            // sitting in the layout reserving space for the "~" case.
            visible: centerCapsule.activeCenterModule === "apps" && bar.appClass !== ""
            opacity: bar.centerMode === "normal" && centerCapsule.activeCenterModule === "apps" && bar.appClass !== "" ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: 100 }
            }

            IconImage {
                implicitSize: 14
                source: bar.iconForClass(bar.appClass)
                visible: source !== ""
                smooth: true
                mipmap: true
                Layout.alignment: Qt.AlignVCenter
            }

            Text {
                text: bar.appTitle
                color: Palette.Theme.textPrimary
                font.family: Palette.Theme.fontMono
                font.pixelSize: 12
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                Layout.maximumWidth: 200
                Layout.alignment: Qt.AlignVCenter
            }
        }

        Text {
            id: desktopContent
            anchors.centerIn: parent
            text: "~"
            color: Palette.Theme.textPrimary
            font.family: Palette.Theme.fontMono
            font.pixelSize: 12
            font.weight: Font.DemiBold
            // The only child on screen in this state — nothing else can
            // push it off-center.
            visible: centerCapsule.activeCenterModule === "apps" && bar.appClass === ""
            opacity: bar.centerMode === "normal" && centerCapsule.activeCenterModule === "apps" && bar.appClass === "" ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: 100 }
            }
        }

        Item {
            id: cavaContent
            anchors.centerIn: parent
            implicitWidth: bar.mediaPlaying ? cavaVisualizer.implicitWidth : silenceText.implicitWidth
            implicitHeight: Math.max(cavaVisualizer.implicitHeight, silenceText.implicitHeight)
            visible: centerCapsule.activeCenterModule === "cava"
            opacity: bar.centerMode === "normal" && centerCapsule.activeCenterModule === "cava" ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: 100 }
            }

            // The visualizer only ever runs while something is actually
            // playing — with nothing to visualize it just sat there
            // painted on one stale frame, which read as frozen/broken.
            Cava {
                id: cavaVisualizer
                anchors.centerIn: parent
                // The horizontal notch (and this cava instance inside it)
                // stays instantiated but hidden when the bar is vertical —
                // don't let it keep a cava process running behind the
                // vertical bar's own visualizer.
                active: bar.mediaPlaying && cavaContent.visible && !bar.vertical
                visible: bar.mediaPlaying
                opacity: bar.mediaPlaying ? 1 : 0
                Behavior on opacity {
                    NumberAnimation { duration: 140 }
                }
            }

            Text {
                id: silenceText
                anchors.centerIn: parent
                text: "Enjoy Silence"
                visible: !bar.mediaPlaying
                opacity: !bar.mediaPlaying ? 1 : 0
                color: Palette.Theme.textMuted
                font.family: Palette.Theme.fontMono
                font.pixelSize: 12
                Behavior on opacity {
                    NumberAnimation { duration: 140 }
                }
            }
        }

        RowLayout {
            id: clockContent
            anchors.centerIn: parent
            spacing: 8
            visible: centerCapsule.activeCenterModule === "clock"
            opacity: bar.centerMode === "normal" && centerCapsule.activeCenterModule === "clock" ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: 100 }
            }

            Clock {}
        }

        MouseArea {
            id: centerScrollArea
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor

            // A trackpad swipe fires many small wheel deltas in quick
            // succession; without this gate each one would yank the module
            // index and restart the crossfade/width animations mid-flight,
            // reading as stutter. One swipe now advances a single step.
            property bool wheelLocked: false

            Timer {
                id: wheelUnlock
                interval: 260
                onTriggered: centerScrollArea.wheelLocked = false
            }

            onWheel: wheel => {
                wheel.accepted = true;
                if (bar.centerMode !== "normal" || wheelLocked)
                    return;
                var len = bar.centerModules.length;
                var dir = wheel.angleDelta.y > 0 ? 1 : -1;
                bar.centerModuleIndex = (bar.centerModuleIndex + dir + len) % len;
                wheelLocked = true;
                wheelUnlock.restart();
            }
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton) {
                    bar.closeControlCenter();
                    if (bar.mediaPanel)
                        bar.mediaPanel.toggleMediaPanel();
                    return;
                }

                bar.toggleControlCenter();
            }
        }

        Connections {
            target: bar.controlCenter
            enabled: bar.controlCenter !== null
            function onAboutToOpen() { bar.centerMode = "controlCenter"; }
            function onAboutToClose() { bar.centerMode = "normal"; }
        }

        Connections {
            target: bar.powerMenu
            enabled: bar.powerMenu !== null
            function onAboutToOpen() { bar.centerMode = "powerMenu"; }
            function onAboutToClose() { bar.centerMode = "normal"; }
        }

        Connections {
            target: bar.mediaPanel
            enabled: bar.mediaPanel !== null
            function onAboutToOpen() { bar.centerMode = "mediaPanel"; }
            function onAboutToClose() { bar.centerMode = "normal"; }
        }

        Connections {
            target: bar.toolMenu
            enabled: bar.toolMenu !== null
            function onAboutToOpen() { bar.centerMode = "toolMenu"; }
            function onAboutToClose() { bar.centerMode = "normal"; }
        }
    }

    // Recording badge — pinned just outside the notch's right edge (not
    // inside it) so it can never overlap centered content, no matter how
    // narrow the current module's width is.
    Rectangle {
        id: recordingDot
        visible: bar.isRecording && !bar.vertical
        anchors.left: centerCapsule.right
        anchors.leftMargin: 6
        anchors.verticalCenter: centerCapsule.verticalCenter
        width: 7
        height: 7
        radius: 3.5
        color: Palette.Theme.errorColor

        SequentialAnimation on opacity {
            running: bar.isRecording
            loops: Animation.Infinite
            NumberAnimation {
                to: 0.15
                duration: 650
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                to: 1
                duration: 650
                easing.type: Easing.InOutSine
            }
        }

        Process {
            id: stopRecording
            onExited: bar.checkRecording()
        }

        MouseArea {
            // The dot itself is only 7px — pad the hit target so it's
            // actually clickable.
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            onClicked: stopRecording.exec(["bash", "-lc", "~/.config/quickshell/scripts/record.sh"])
        }
    }
}
