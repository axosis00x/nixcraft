import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Networking
import QtQuick
import QtQuick.Layouts
import "../../components/material"
import "../../theme" as Palette
import "../notification"

Item {
    id: root

    anchors.fill: parent
    visible: false

    property real maxWidth: 4000
    property real maxHeight: 4000
    property var notificationCenter
    property var bar
    property var idleService: null
    property string powerProfile: "balanced"
    property bool powerProfileLoaded: false
    property real volumeValue: 0.5
    property bool volumeMuted: false
    property real brightnessValue: 0.5
    property real micValue: 0.5
    property bool micMuted: false
    property string detailMode: "none"

    // Wi-Fi, wired and Bluetooth state comes live from Quickshell's
    // NetworkManager and BlueZ bindings (as the bar's NetworkIcon does) —
    // no polling, no parsing nmcli/bluetoothctl output, and passwords go
    // over D-Bus rather than onto a command line.
    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) || null
    readonly property var wiredDevice: Networking.devices.values.find(d => d.type === DeviceType.Wired) || null
    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property bool ethernetConnected: wiredDevice ? wiredDevice.connected : false
    readonly property var bluetoothAdapter: Bluetooth.defaultAdapter
    readonly property bool bluetoothLoaded: bluetoothAdapter !== null
    readonly property bool bluetoothEnabled: bluetoothAdapter ? bluetoothAdapter.enabled : false
    readonly property bool wifiScanning: wifiDevice ? wifiDevice.scannerEnabled : false
    readonly property bool bluetoothScanning: bluetoothAdapter ? bluetoothAdapter.discovering : false

    // Detail lists: connected first, then saved/paired, then the rest.
    readonly property var wifiNetworks: wifiDevice ? wifiDevice.networks.values.filter(n => n.name !== "").sort((a, b) => wifiRank(b) - wifiRank(a) || b.signalStrength - a.signalStrength) : []
    // Unpaired devices only once they advertise a real name, so the list
    // isn't a wall of bare addresses while discovering.
    readonly property var bluetoothDevices: bluetoothAdapter ? bluetoothAdapter.devices.values.filter(d => d.paired || d.connected || d.deviceName !== "").sort((a, b) => bluetoothRank(b) - bluetoothRank(a) || a.name.localeCompare(b.name)) : []

    // Wi-Fi password prompt.
    property var authNetwork: null
    property bool authVisible: false
    property bool authBusy: false
    property string authError: ""

    // The network / device a connect is in flight for. A first attempt on
    // an unsaved network remembers that, so a failure can drop the profile
    // NetworkManager saved with the bad password.
    property var pendingNetwork: null
    property bool pendingWasKnown: false
    // Prompt dismissed while connecting: report a failure as a
    // notification instead of popping the prompt back up.
    property bool pendingQuiet: false
    property var pendingDevice: null
    property bool pendingDeviceConnecting: false
    property bool showVolumeOsdOnRead: false
    property bool showBrightnessOsdOnRead: false
    property bool showMicOsdOnRead: false
    readonly property bool dndEnabled: toggleState.dnd
    // Purely a mirror of toggleState.hyprsunset (readonly, never assigned
    // directly) so it can't fall out of sync with what's on disk — the
    // same pattern services/BarLayoutService.qml uses for `vertical`.
    readonly property bool hyprsunsetEnabled: toggleState.hyprsunset
    property string powerProfilePending: ""
    // Owned and persisted by IdleService, which is what actually enforces it.
    readonly property bool keepAwake: idleService ? idleService.keepAwake : false

    readonly property real minLevel: 0.05
    readonly property var notifications: notificationCenter ? notificationCenter.notifications : []
    readonly property int notificationCount: notificationCenter ? notificationCenter.count : 0
    readonly property bool showingDetail: detailMode !== "none"

    implicitWidth: Math.max(380, Math.min(maxWidth - 2, 450))
    implicitHeight: showingDetail ? Math.max(320, Math.min(maxHeight - 4, 400)) : Math.max(440, Math.min(maxHeight - 4, 480))

    signal aboutToOpen
    signal aboutToClose

    // hyprsunsetEnabled is otherwise pure in-memory UI state, so a
    // quickshell reload used to forget it even though hyprsunset itself
    // keeps running unaffected — this just resyncs the toggle's visual
    // state, no need to re-issue the temperature command. Written to
    // explicitly (only from toggleHyprsunset()) rather than reactively on
    // every adapter change — the latter also fires while the file is still
    // loading, which was clobbering the just-loaded value back to default.
    FileView {
        id: toggleStateFile
        path: Quickshell.cachePath("control-center-toggles.json")
        watchChanges: false
        blockLoading: true

        JsonAdapter {
            id: toggleState
            property bool hyprsunset: false
            property bool keepAwake: false
            property bool dnd: false
        }
    }

    Component.onCompleted: {
        readPowerProfile();
        if (toggleState.dnd) {
            if (root.notificationCenter)
                root.notificationCenter.setDnd(true);
            setExternalDnd(true);
        }
        if (toggleState.hyprsunset) {
            hyprsunsetSet.exec(["hyprctl", "hyprsunset", "temperature", "2800"]);
        }
    }

    function clampLevel(value) {
        return Math.max(minLevel, Math.min(1, value));
    }

    function refreshAll() {
        readPowerProfile();
        readVolume();
        readBrightness();
        readMic();
        syncDnd();
    }

    function syncVolumeFromBar(value, muted) {
        volumeValue = clampLevel(value);
        volumeMuted = muted;
    }

    function syncBrightnessFromBar(value) {
        brightnessValue = clampLevel(value);
    }

    function syncFromBar() {
        if (!root.bar)
            return;
        syncVolumeFromBar(root.bar.currentVolume, root.bar.currentVolumeMuted);
        syncBrightnessFromBar(root.bar.currentBrightness);
    }

    function openControlCenter() {
        if (root.bar && typeof root.bar.closeLauncher === "function")
            root.bar.closeLauncher(true);
        if (root.visible)
            return;
        aboutToOpen();
        syncFromBar();
        refreshAll();
        visible = true;
    }

    function closeControlCenter(immediate) {
        if (!root.visible)
            return;
        aboutToClose();
        detailMode = "none";
        if (immediate) {
            closeTimer.stop();
            visible = false;
            return;
        }
        closeTimer.restart();
    }

    function toggleControlCenter() {
        if (visible)
            closeControlCenter();
        else
            openControlCenter();
    }

    function toggleWifi() {
        Networking.wifiEnabled = !Networking.wifiEnabled;
    }

    function toggleNetwork() {
        toggleWifi();
    }

    function openWifiList() {
        detailMode = detailMode === "wifi" ? "none" : "wifi";
    }

    // Scan / discover only while the matching list is open.
    onDetailModeChanged: {
        if (wifiDevice)
            wifiDevice.scannerEnabled = detailMode === "wifi";
        setDiscovering(detailMode === "bluetooth");
        if (detailMode !== "wifi")
            cancelWifiAuth();
    }
    onWifiDeviceChanged: if (wifiDevice)
        wifiDevice.scannerEnabled = detailMode === "wifi"
    onBluetoothEnabledChanged: setDiscovering(detailMode === "bluetooth")

    // ── Wi-Fi ───────────────────────────────────────────────────────
    readonly property var enterpriseSecurity: [WifiSecurityType.Wpa3SuiteB192, WifiSecurityType.Wpa2Eap, WifiSecurityType.WpaEap, WifiSecurityType.DynamicWep, WifiSecurityType.Leap]

    function wifiRank(n) {
        return n.connected ? 2 : (n.known ? 1 : 0);
    }

    function isOpenNetwork(n) {
        return n.security === WifiSecurityType.Open || n.security === WifiSecurityType.Owe;
    }

    function isEnterpriseNetwork(n) {
        return enterpriseSecurity.indexOf(n.security) !== -1;
    }

    function isWepNetwork(n) {
        return n.security === WifiSecurityType.StaticWep;
    }

    // WPA/SAE: 8–63 characters or a 64-digit hex key. WEP: 5/13 characters
    // or 10/26 hex digits. Checked before sending so a typo fails here, not
    // after a 20 s handshake.
    function validPassword(n, psk) {
        if (!n)
            return false;
        if (isWepNetwork(n))
            return psk.length === 5 || psk.length === 13 || (/^[0-9a-fA-F]+$/.test(psk) && (psk.length === 10 || psk.length === 26));
        return (psk.length >= 8 && psk.length <= 63) || /^[0-9a-fA-F]{64}$/.test(psk);
    }

    function passwordHint(n) {
        return n && isWepNetwork(n) ? "WEP keys are 5 or 13 characters (10 or 26 hex digits)" : "At least 8 characters";
    }

    function wifiSection(n) {
        return n.connected ? "Connected" : (n.known ? "Saved" : "Available");
    }

    function wifiSignalIcon(n) {
        var s = n.signalStrength;
        return s >= 0.75 ? "signal_wifi_4_bar" : s >= 0.5 ? "network_wifi_3_bar" : s >= 0.25 ? "network_wifi_2_bar" : "network_wifi_1_bar";
    }

    function wifiSubtitle(n) {
        if (n.stateChanging)
            return n.connected ? "Disconnecting…" : "Connecting…";
        return [isOpenNetwork(n) ? "Open" : WifiSecurityType.toString(n.security), Math.round(n.signalStrength * 100) + "%"].join("  ·  ");
    }

    function wifiAction(n) {
        if (n.stateChanging)
            return "…";
        return n.connected ? "Disconnect" : "Connect";
    }

    function activateWifi(n) {
        if (!n || n.stateChanging)
            return;
        if (n.connected) {
            n.disconnect();
            return;
        }
        // 802.1X needs identity/certificates the prompt doesn't collect;
        // hand those to nmtui (floated by the wiremix/nmtui window rule).
        if (isEnterpriseNetwork(n) && !n.known) {
            Quickshell.execDetached(["kitty", "--class", "nmtui", "-e", "nmtui-connect", n.name]);
            return;
        }
        if (n.known || isOpenNetwork(n)) {
            beginConnect(n);
            n.connect();
            return;
        }
        requestWifiAuth(n, "");
    }

    function beginConnect(n) {
        pendingNetwork = n;
        pendingWasKnown = n.known;
        pendingQuiet = false;
        connectTimeout.restart();
    }

    function requestWifiAuth(n, error) {
        authNetwork = n;
        authError = error;
        authBusy = false;
        authVisible = true;
    }

    function submitWifiAuth(psk) {
        if (!authNetwork || authBusy || !validPassword(authNetwork, psk))
            return;
        authBusy = true;
        authError = "";
        beginConnect(authNetwork);
        authNetwork.connectWithPsk(psk);
    }

    function cancelWifiAuth() {
        if (authBusy)
            pendingQuiet = true;
        authVisible = false;
        authBusy = false;
        authError = "";
        authNetwork = null;
    }

    function connectFailureMessage(reason, wasKnown) {
        switch (reason) {
        case ConnectionFailReason.NoSecrets:
            return wasKnown ? "The saved password didn't work. Enter the current one." : "Wrong password. Check it and try again.";
        case ConnectionFailReason.WifiAuthTimeout:
            return "The network didn't answer in time. Try again.";
        case ConnectionFailReason.WifiNetworkLost:
            return "Lost the network. Move closer and try again.";
        default:
            return "Couldn't connect to this network.";
        }
    }

    function finishConnect(ok, reason) {
        connectTimeout.stop();
        var n = pendingNetwork;
        var wasKnown = pendingWasKnown;
        pendingNetwork = null;
        if (!n)
            return;
        if (ok) {
            if (authNetwork === n)
                cancelWifiAuth();
            return;
        }
        // NetworkManager keeps the profile from a failed first attempt,
        // bad password and all, and would silently retry it next time.
        if (!wasKnown && n.known)
            n.forget();
        if (isOpenNetwork(n) || pendingQuiet) {
            notify("Wi-Fi", "Couldn't connect to " + n.name + ". " + connectFailureMessage(reason, wasKnown));
            return;
        }
        requestWifiAuth(n, connectFailureMessage(reason, wasKnown));
    }

    function notify(title, body) {
        Quickshell.execDetached(["notify-send", "-a", "Control center", title, body]);
    }

    // ── Bluetooth ───────────────────────────────────────────────────
    function setDiscovering(on) {
        var a = bluetoothAdapter;
        if (a && a.enabled && a.discovering !== on)
            a.discovering = on;
    }

    function bluetoothRank(d) {
        return d.connected ? 2 : (d.paired ? 1 : 0);
    }

    function bluetoothSection(d) {
        return d.connected ? "Connected" : (d.paired ? "Paired" : "Available");
    }

    function bluetoothBusy(d) {
        return d.pairing || d.state === BluetoothDeviceState.Connecting || d.state === BluetoothDeviceState.Disconnecting;
    }

    // BlueZ icon names -> Material Symbols.
    function bluetoothDeviceIcon(d) {
        var map = {
            "audio-headset": "headset_mic",
            "audio-headphones": "headphones",
            "audio-card": "speaker",
            "input-keyboard": "keyboard",
            "input-mouse": "mouse",
            "input-gaming": "sports_esports",
            "input-tablet": "stylus",
            "phone": "smartphone",
            "computer": "computer",
            "video-display": "tv"
        };
        return map[d.icon] || "bluetooth";
    }

    function bluetoothSubtitle(d) {
        if (d.pairing)
            return "Pairing…";
        if (d.state === BluetoothDeviceState.Connecting)
            return "Connecting…";
        if (d.state === BluetoothDeviceState.Disconnecting)
            return "Disconnecting…";
        if (d.connected)
            return "Connected" + (d.batteryAvailable ? "  ·  " + Math.round(d.battery * 100) + "% battery" : "");
        return d.paired ? "Paired" : "Available";
    }

    function bluetoothAction(d) {
        if (bluetoothBusy(d))
            return "…";
        return d.connected ? "Disconnect" : (d.paired ? "Connect" : "Pair");
    }

    // Unpaired devices are paired, trusted (so they reconnect on their own
    // later) and connected in one go; see the Connections on pendingDevice.
    function activateBluetooth(d) {
        if (!d || bluetoothBusy(d))
            return;
        if (d.connected) {
            d.disconnect();
            return;
        }
        pendingDevice = d;
        pendingDeviceConnecting = false;
        bluetoothTimeout.restart();
        if (d.paired)
            d.connect();
        else
            d.pair();
    }

    function finishBluetooth(ok) {
        bluetoothTimeout.stop();
        var d = pendingDevice;
        pendingDevice = null;
        pendingDeviceConnecting = false;
        if (d && !ok)
            notify("Bluetooth", "Couldn't connect to " + d.name);
    }

    function readPowerProfile() {
        powerProfileRead.exec(["powerprofilesctl", "get"]);
    }

    function parsePowerProfile(data) {
        if (powerProfilePending !== "")
            return;
        powerProfile = data.trim() || powerProfile;
        powerProfileLoaded = true;
    }

    function cyclePowerProfile() {
        var next = "balanced";
        if (powerProfile === "balanced")
            next = "power-saver";
        else if (powerProfile === "power-saver")
            next = "performance";
        setPowerProfile(next);
    }

    function setPowerProfile(profile) {
        if (profile === powerProfile && powerProfilePending === "")
            return;
        powerProfile = profile;
        powerProfileLoaded = true;
        powerProfilePending = profile;
        powerProfileSet.exec(["powerprofilesctl", "set", profile]);
    }

    function toggleBluetooth() {
        var a = bluetoothAdapter;
        if (!a)
            return;
        if (a.enabled) {
            a.enabled = false;
            return;
        }
        // BlueZ refuses to power on while rfkill blocks the radio.
        if (a.state === BluetoothAdapterState.Blocked)
            rfkillUnblock.exec(["rfkill", "unblock", "bluetooth"]);
        else
            a.enabled = true;
    }

    function openBluetoothList() {
        detailMode = detailMode === "bluetooth" ? "none" : "bluetooth";
    }

    function closeDetailWindow(animated) {
        detailMode = "none";
    }

    function readVolume() {
        volumeRead.exec(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]);
    }

    function parseVolume(data) {
        var match = data.match(/Volume:\s+([0-9.]+)/);
        if (!match || match.length < 2)
            return;
        var level = Number(match[1]);
        if (isNaN(level))
            return;
        volumeValue = level;
        volumeMuted = /MUTED/.test(data);
        if (root.bar && typeof root.bar.syncVolumeFromControlCenter === "function")
            root.bar.syncVolumeFromControlCenter(volumeValue, volumeMuted, showVolumeOsdOnRead);
        showVolumeOsdOnRead = false;
    }

    function setVolume(value) {
        volumeValue = clampLevel(value);
        showVolumeOsdOnRead = true;
        if (root.bar && typeof root.bar.syncVolumeFromControlCenter === "function")
            root.bar.syncVolumeFromControlCenter(volumeValue, volumeMuted, true);
        volumeSet.exec(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", Math.round(volumeValue * 100) + "%"]);
    }

    function toggleMute() {
        showVolumeOsdOnRead = true;
        volumeMute.exec(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
    }

    // Own window class so Hyprland floats and centers it (windowrules.lua).
    function openWiremix() {
        wiremixLaunch.exec(["kitty", "--class", "wiremix", "-e", "wiremix"]);
    }

    function readBrightness() {
        brightnessRead.exec(["brightnessctl", "-m"]);
    }

    function parseBrightness(data) {
        var parts = data.trim().split(",");
        if (parts.length < 5)
            return;
        var percent = Number(parts[3].replace("%", ""));
        if (isNaN(percent))
            return;
        brightnessValue = percent / 100;
        if (root.bar && typeof root.bar.syncBrightnessFromControlCenter === "function")
            root.bar.syncBrightnessFromControlCenter(brightnessValue, showBrightnessOsdOnRead);
        showBrightnessOsdOnRead = false;
    }

    function setBrightness(value) {
        brightnessValue = clampLevel(value);
        showBrightnessOsdOnRead = true;
        if (root.bar && typeof root.bar.syncBrightnessFromControlCenter === "function")
            root.bar.syncBrightnessFromControlCenter(brightnessValue, true);
        brightnessSet.exec(["brightnessctl", "set", Math.round(brightnessValue * 100) + "%"]);
    }

    function readMic() {
        micRead.exec(["wpctl", "get-volume", "@DEFAULT_AUDIO_SOURCE@"]);
    }

    function parseMic(data) {
        var match = data.match(/Volume:\s+([0-9.]+)/);
        if (!match || match.length < 2)
            return;
        var level = Number(match[1]);
        if (isNaN(level))
            return;
        micValue = level;
        micMuted = /MUTED/.test(data);
        showMicOsdOnRead = false;
    }

    function setMic(value) {
        micValue = clampLevel(value);
        showMicOsdOnRead = true;
        micSet.exec(["wpctl", "set-volume", "@DEFAULT_AUDIO_SOURCE@", Math.round(micValue * 100) + "%"]);
    }

    function toggleMicMute() {
        showMicOsdOnRead = true;
        micMute.exec(["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"]);
    }

    function micIcon() {
        return root.micMuted ? "\ue02b" : "\ue029";
    }

    function wifiIcon() {
        return root.wifiEnabled ? "\ue1ba" : "\ue648";
    }

    function networkIcon() {
        return root.ethernetConnected ? ethernetIcon() : wifiIcon();
    }

    function networkActive() {
        return root.ethernetConnected || root.wifiEnabled;
    }

    // The connected network's name rather than just "Wi-Fi".
    function networkSubtitle() {
        var current = root.wifiDevice ? root.wifiDevice.networks.values.find(n => n.connected) : null;
        if (root.ethernetConnected)
            return current ? "Wired + " + current.name : "Wired";
        if (!root.wifiEnabled)
            return "Off";
        return current ? current.name : "Not connected";
    }

    function gameModeIcon() {
        return "\ue6ec";
    }

    function powerIcon() {
        if (root.powerProfile === "power-saver")
            return "\ue9e4";
        if (root.powerProfile === "performance")
            return "\uea0b";
        return "\ue8d4";
    }

    // Each power profile gets its own silhouette, not just a color swap —
    // power-saver is a calm full circle, performance is a sharp-cornered
    // square, balanced sits in between as a plain rounded square.
    function powerProfileShapeRadius() {
        if (root.powerProfile === "power-saver")
            return 31;
        if (root.powerProfile === "performance")
            return 4;
        return Palette.Theme.radiusMedium;
    }

    function bluetoothTileSubtitle() {
        if (!root.bluetoothLoaded)
            return "Unavailable";
        if (!root.bluetoothEnabled)
            return "Off";
        var connected = root.bluetoothDevices.filter(d => d.connected);
        return connected.length === 1 ? connected[0].name : connected.length > 1 ? connected.length + " devices" : "On";
    }

    function bluetoothIcon() {
        return "\ue1a7";
    }

    function syncDnd() {
        if (root.notificationCenter && typeof root.notificationCenter.setDnd === "function")
            root.notificationCenter.setDnd(toggleState.dnd);
    }

    function toggleDnd() {
        toggleState.dnd = !toggleState.dnd;
        toggleStateFile.writeAdapter();
        if (root.notificationCenter && typeof root.notificationCenter.setDnd === "function")
            root.notificationCenter.setDnd(toggleState.dnd);
        setExternalDnd(toggleState.dnd);
    }

    function setExternalDnd(enabled) {
        dndSet.exec(["sh", "-c", enabled ? "command -v makoctl >/dev/null 2>&1 && makoctl mode -a do-not-disturb; command -v swaync-client >/dev/null 2>&1 && swaync-client -dn" : "command -v makoctl >/dev/null 2>&1 && makoctl mode -r do-not-disturb; command -v swaync-client >/dev/null 2>&1 && swaync-client -df"]);
    }

    function clearAllNotifications() {
        if (root.notificationCenter)
            root.notificationCenter.clearAll();
        notificationClear.exec(["sh", "-c", "command -v swaync-client >/dev/null 2>&1 && swaync-client -C"]);
    }

    function toggleHyprsunset() {
        toggleState.hyprsunset = !toggleState.hyprsunset;
        toggleStateFile.writeAdapter();
        if (hyprsunsetEnabled) {
            hyprsunsetSet.exec(["hyprctl", "hyprsunset", "temperature", "2800"]);
        } else {
            // Restarting the daemon (the old approach) is what caused the
            // flash: Wayland only allows a single gamma-control client, so
            // killing hyprsunset makes the compositor immediately snap back
            // to neutral gamma, then hyprsunset has to relaunch and reclaim
            // control ~0.3s later — a hard flash no matter what value gets
            // reapplied afterward. Sending a direct hyprctl request instead
            // (same as the "on" branch) changes the temperature in place,
            // with no client handoff and no flash. The trade-off: once
            // manually set this way, the daemon stops auto-advancing through
            // hyprsunset.conf's remaining profiles for the rest of the
            // session (resumes on next login/restart) — acceptable, since a
            // guaranteed flash on every toggle is worse than a schedule that
            // needs a nudge later.
            hyprsunsetSet.exec(["sh", "-c", ["conf=\"$HOME/.config/hypr/hyprsunset.conf\"", "now=$(date +%H%M)", "t=$(awk -v now=\"$now\" '/time[[:space:]]*=/{gsub(/[^0-9:]/,\"\");n=split($0,a,\":\");tm=a[1]a[2];next}/temperature[[:space:]]*=/{gsub(/[^0-9]/,\"\");temp=$0;if(first==\"\")first=temp;last=temp;if(tm<=now)best=temp}END{print (best!=\"\"?best:last)}' \"$conf\")", "[ -n \"$t\" ] || t=4000", "hyprctl hyprsunset temperature \"$t\"",].join("; ")]);
        }
    }

    function hyprsunsetIcon() {
        return "";
    }

    function toggleKeepAwake() {
        if (root.idleService)
            root.idleService.toggleKeepAwake();
    }

    function keepAwakeIcon() {
        return "\uefef";
    }
    function ethernetIcon() {
        return "\ueb2f";
    }

    function volumeIcon() {
        if (root.volumeMuted || root.volumeValue <= 0.01)
            return "\ue04f";
        if (root.volumeValue < 0.5)
            return "\ue04d";
        return "\ue050";
    }

    function brightnessIcon() {
        if (root.brightnessValue < 0.5)
            return "\ue1ab";
        return "\ue1ac";
    }

    Connections {
        target: root.pendingNetwork
        ignoreUnknownSignals: true
        function onConnectionFailed(reason) {
            root.finishConnect(false, reason);
        }
        function onConnectedChanged() {
            if (root.pendingNetwork && root.pendingNetwork.connected)
                root.finishConnect(true, ConnectionFailReason.Unknown);
        }
    }

    // Backstop for a connect that neither succeeds nor reports failure.
    Timer {
        id: connectTimeout
        interval: 45000
        onTriggered: root.finishConnect(false, ConnectionFailReason.WifiAuthTimeout)
    }

    Connections {
        target: root.pendingDevice
        ignoreUnknownSignals: true
        function onPairedChanged() {
            var d = root.pendingDevice;
            if (d && d.paired) {
                d.trusted = true;
                d.connect();
            }
        }
        function onPairingChanged() {
            var d = root.pendingDevice;
            if (d && !d.pairing && !d.paired)
                root.finishBluetooth(false);
        }
        function onStateChanged() {
            var d = root.pendingDevice;
            if (!d)
                return;
            if (d.state === BluetoothDeviceState.Connecting)
                root.pendingDeviceConnecting = true;
            else if (d.state === BluetoothDeviceState.Disconnected && root.pendingDeviceConnecting)
                root.finishBluetooth(false);
        }
        function onConnectedChanged() {
            if (root.pendingDevice && root.pendingDevice.connected)
                root.finishBluetooth(true);
        }
    }

    Timer {
        id: bluetoothTimeout
        interval: 40000
        onTriggered: root.finishBluetooth(false)
    }

    Process {
        id: rfkillUnblock
        onExited: if (root.bluetoothAdapter)
            root.bluetoothAdapter.enabled = true
    }

    Timer {
        id: closeTimer
        interval: 180
        onTriggered: root.visible = false
    }

    Process {
        id: powerProfileRead
        command: ["powerprofilesctl", "get"]

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root.parsePowerProfile(data)
        }
    }

    Process {
        id: powerProfileSet
        onExited: {
            root.powerProfilePending = "";
            root.readPowerProfile();
        }
    }

    Process {
        id: volumeRead
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root.parseVolume(data)
        }
    }

    Process {
        id: volumeSet
        onExited: root.readVolume()
    }

    Process {
        id: volumeMute
        onExited: root.readVolume()
    }

    Process {
        id: micRead
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SOURCE@"]

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root.parseMic(data)
        }
    }

    Process {
        id: micSet
        onExited: root.readMic()
    }

    Process {
        id: micMute
        onExited: root.readMic()
    }

    Process {
        id: wiremixLaunch
    }

    Process {
        id: dndSet
    }

    Process {
        id: notificationClear
    }

    Process {
        id: brightnessRead
        command: ["brightnessctl", "-m"]

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root.parseBrightness(data)
        }
    }

    Process {
        id: brightnessSet
        onExited: root.readBrightness()
    }

    Process {
        id: hyprsunsetSet
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Item {
            id: contentArea
            Layout.fillWidth: true
            Layout.fillHeight: true

            Item {
                id: normalView
                anchors.fill: parent
                opacity: root.showingDetail ? 0 : 1
                scale: root.showingDetail ? 0.98 : 1
                transformOrigin: Item.Top
                enabled: !root.showingDetail

                Behavior on opacity {
                    EffectMotion {
                        fast: false
                    }
                }

                Behavior on scale {
                    SpatialMotion {
                        bouncy: true
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    anchors.bottomMargin: 16
                    anchors.topMargin: 18
                    spacing: 10

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Tile {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 64
                                icon: root.networkIcon()
                                title: "Network"
                                subtitle: root.networkSubtitle()
                                active: root.networkActive()
                                onClicked: root.toggleNetwork()
                                onRightClicked: root.openWifiList()
                            }

                            Tile {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 64
                                icon: root.bluetoothIcon()
                                title: "Bluetooth"
                                subtitle: root.bluetoothTileSubtitle()
                                active: root.bluetoothLoaded && root.bluetoothEnabled
                                onClicked: root.toggleBluetooth()
                                onRightClicked: root.openBluetoothList()
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Surface {
                                Layout.fillWidth: true
                                Layout.preferredHeight: slidersInner.implicitHeight + 20
                                radius: Palette.Theme.radiusMedium
                                color: Palette.Theme.surfaceContainerLow
                                tintOpacity: 0.025

                                ColumnLayout {
                                    id: slidersInner
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 2

                                    ControlSlider {
                                        Layout.fillWidth: true
                                        iconGlyph: root.volumeIcon()
                                        value: root.volumeValue
                                        onIconClicked: root.toggleMute()
                                        onIconRightClicked: root.openWiremix()
                                        onValueRequested: value => root.setVolume(value)
                                    }

                                    ControlSlider {
                                        Layout.fillWidth: true
                                        iconGlyph: root.brightnessIcon()
                                        value: root.brightnessValue
                                        onValueRequested: value => root.setBrightness(value)
                                    }

                                    ControlSlider {
                                        Layout.fillWidth: true
                                        iconGlyph: root.micIcon()
                                        value: root.micValue
                                        onIconClicked: root.toggleMicMute()
                                        onValueRequested: value => root.setMic(value)
                                    }
                                }
                            }

                            Surface {
                                Layout.preferredHeight: slidersInner.implicitHeight + 20
                                Layout.preferredWidth: slidersInner.implicitHeight + 20
                                radius: Palette.Theme.radiusMedium
                                color: Palette.Theme.surfaceContainerLow
                                tintOpacity: 0.025

                                GridLayout {
                                    id: gridInner
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    columns: 2
                                    columnSpacing: 10
                                    rowSpacing: 10

                                    Tile {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        iconOnly: true
                                        icon: root.hyprsunsetIcon()
                                        title: "Night"
                                        tint: Palette.Theme.secondaryText
                                        active: root.hyprsunsetEnabled
                                        onClicked: root.toggleHyprsunset()
                                    }

                                    Tile {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        iconOnly: true
                                        icon: root.gameModeIcon()
                                        title: "Game Mode"
                                        tint: Palette.Theme.info
                                        active: root.dndEnabled
                                        onClicked: root.toggleDnd()
                                    }

                                    Tile {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        iconOnly: true
                                        icon: root.keepAwakeIcon()
                                        title: "Keep Awake"
                                        tint: Palette.Theme.success
                                        active: root.keepAwake
                                        onClicked: root.toggleKeepAwake()
                                    }

                                    Tile {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        iconOnly: true
                                        icon: root.powerIcon()
                                        title: "Power"
                                        tint: Palette.Theme.warning
                                        active: root.powerProfileLoaded
                                        shapeRadius: root.powerProfileShapeRadius()
                                        pulseKey: root.powerProfile
                                        onClicked: root.cyclePowerProfile()
                                    }
                                }
                            }
                        }
                    }

                    // Notifications: a tonal card like the groups above, with a
                    // header (icon, title, count, DND state, clear) and either
                    // the list or a calm empty state.
                    Surface {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.topMargin: 2
                        // No container fill — the cards carry the surface.
                        color: "transparent"
                        tintOpacity: 0

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 0
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.leftMargin: 4
                                spacing: 8

                                Text {
                                    text: root.dndEnabled ? "notifications_off" : "notifications"
                                    color: root.dndEnabled ? Palette.Theme.textMuted : Palette.Theme.accent
                                    font.family: Palette.Theme.fontIcons
                                    font.pixelSize: Palette.Theme.iconSize
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Text {
                                    text: "Notifications"
                                    color: Palette.Theme.textPrimary
                                    font.family: Palette.Theme.fontSans
                                    font.pixelSize: Palette.Theme.fontSizeBody
                                    font.weight: Font.DemiBold
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                // Count badge.
                                Rectangle {
                                    visible: root.notificationCount > 0
                                    Layout.alignment: Qt.AlignVCenter
                                    implicitWidth: Math.max(20, countText.implicitWidth + 12)
                                    implicitHeight: 20
                                    radius: height / 2
                                    color: Palette.Theme.accentTonal

                                    Text {
                                        id: countText
                                        anchors.centerIn: parent
                                        text: root.notificationCount
                                        color: Palette.Theme.accent
                                        font.family: Palette.Theme.fontSans
                                        font.pixelSize: Palette.Theme.fontSizeXs
                                        font.weight: Font.DemiBold
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                }

                                ActionChip {
                                    label: "Clear all"
                                    visible: root.notificationCount > 0
                                    onClicked: root.clearAllNotifications()
                                }
                            }

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                // Empty state.
                                Column {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    visible: root.notificationCount === 0

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: root.dndEnabled ? "do_not_disturb_on" : "notifications_paused"
                                        color: Palette.Theme.textMuted
                                        font.family: Palette.Theme.fontIcons
                                        font.pixelSize: 30
                                        opacity: 0.6
                                    }

                                    Text {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        text: root.dndEnabled ? "Do not disturb is on" : "You're all caught up"
                                        color: Palette.Theme.textSecondary
                                        font.family: Palette.Theme.fontSans
                                        font.pixelSize: Palette.Theme.fontSizeBody
                                    }
                                }

                                ListView {
                                    anchors.fill: parent
                                    clip: true
                                    spacing: 10
                                    model: root.notificationCenter ? root.notificationCenter.groupedNotifications : []
                                    visible: root.notificationCount > 0
                                    reuseItems: true
                                    cacheBuffer: 320

                                    delegate: NotificationGroupCard {
                                        required property var modelData
                                        width: ListView.view.width
                                        notificationCenter: root.notificationCenter
                                        group: modelData
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Item {
                id: detailView
                anchors.fill: parent
                anchors.margins: 12
                opacity: root.showingDetail ? 1 : 0
                scale: root.showingDetail ? 1 : 0.98
                transformOrigin: Item.Top
                enabled: root.showingDetail

                Behavior on opacity {
                    EffectMotion {
                        fast: false
                    }
                }

                Behavior on scale {
                    SpatialMotion {
                        bouncy: true
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        IconButton {
                            icon: "\ue5c4"
                            implicitWidth: 28
                            implicitHeight: 28
                            onClicked: root.closeDetailWindow(true)
                        }

                        Text {
                            text: root.detailMode === "wifi" ? "Wi-Fi" : "Bluetooth"
                            color: Palette.Theme.textPrimary
                            font.family: Palette.Theme.fontSans
                            font.pixelSize: Palette.Theme.fontSizeBody
                            font.weight: Font.DemiBold
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        ToggleSwitch {
                            Layout.alignment: Qt.AlignVCenter
                            checked: root.detailMode === "wifi" ? root.wifiEnabled : root.bluetoothEnabled
                            onToggled: {
                                if (root.detailMode === "wifi")
                                    root.toggleWifi();
                                else
                                    root.toggleBluetooth();
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Text {
                            anchors.centerIn: parent
                            text: root.detailMode === "wifi" ? (!root.wifiEnabled ? "Wi-Fi is off" : root.wifiScanning ? "Scanning…" : "No networks") : (!root.bluetoothEnabled ? "Bluetooth is off" : root.bluetoothScanning ? "Looking for devices…" : "No devices")
                            color: Palette.Theme.textMuted
                            font.family: Palette.Theme.fontSans
                            font.pixelSize: Palette.Theme.fontSizeSmall
                            visible: detailList.count === 0
                        }

                        ListView {
                            id: detailList

                            anchors.fill: parent
                            clip: true
                            spacing: 0
                            // Live NetworkManager / BlueZ objects, so rows
                            // update in place as state changes.
                            model: root.detailMode === "wifi" ? root.wifiNetworks : root.bluetoothDevices
                            cacheBuffer: 240
                            currentIndex: -1

                            HoverHandler {
                                id: detailHover
                            }

                            highlightFollowsCurrentItem: false
                            highlight: MovingHighlight {
                                target: detailHover.hovered && detailList.currentItem ? detailList.currentItem.row : null
                                radius: Palette.Theme.radiusSmall
                            }

                            delegate: Column {
                                id: entry

                                required property var modelData
                                required property int index

                                readonly property bool wifi: root.detailMode === "wifi"
                                readonly property string section: wifi ? root.wifiSection(modelData) : root.bluetoothSection(modelData)
                                readonly property var previous: index > 0 ? ListView.view.model[index - 1] : null
                                readonly property bool firstOfSection: !previous || section !== (wifi ? root.wifiSection(previous) : root.bluetoothSection(previous))
                                property alias row: deviceRow

                                width: ListView.view.width

                                // Section header above the first row of each group.
                                Text {
                                    visible: entry.firstOfSection
                                    text: entry.section
                                    color: Palette.Theme.textMuted
                                    font.family: Palette.Theme.fontMono
                                    font.pixelSize: Palette.Theme.fontSizeXs
                                    font.weight: Font.DemiBold
                                    topPadding: 10
                                    bottomPadding: 4
                                    leftPadding: 4
                                }

                                DeviceRow {
                                    id: deviceRow
                                    width: parent.width
                                    onHoveredChanged: if (hovered)
                                        entry.ListView.view.currentIndex = entry.index
                                    iconGlyph: entry.wifi ? root.wifiSignalIcon(entry.modelData) : root.bluetoothDeviceIcon(entry.modelData)
                                    title: entry.modelData.name
                                    subtitle: entry.wifi ? root.wifiSubtitle(entry.modelData) : root.bluetoothSubtitle(entry.modelData)
                                    active: entry.modelData.connected
                                    actionLabel: entry.wifi ? root.wifiAction(entry.modelData) : root.bluetoothAction(entry.modelData)
                                    onActionClicked: {
                                        if (entry.wifi)
                                            root.activateWifi(entry.modelData);
                                        else
                                            root.activateBluetooth(entry.modelData);
                                    }
                                }
                            }
                        }
                    }
                }

                // Wi-Fi password prompt, over the network list.
                Item {
                    id: authLayer

                    property bool reveal: false
                    readonly property bool hasError: root.authError !== ""
                    readonly property bool valid: root.validPassword(root.authNetwork, authPasswordInput.text)

                    anchors.fill: parent
                    z: 10
                    opacity: root.authVisible ? 1 : 0
                    visible: opacity > 0.01

                    Behavior on opacity {
                        EffectMotion {}
                    }

                    Connections {
                        target: root
                        // Fresh prompt: empty, hidden field with focus.
                        function onAuthVisibleChanged() {
                            if (!root.authVisible)
                                return;
                            authPasswordInput.text = "";
                            authLayer.reveal = false;
                            authPasswordInput.forceActiveFocus();
                        }
                        // Failed attempt: keep what was typed, selected, so
                        // it can be fixed or retyped straight away.
                        function onAuthErrorChanged() {
                            if (root.authError === "")
                                return;
                            authPasswordInput.forceActiveFocus();
                            authPasswordInput.selectAll();
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Palette.Theme.radiusLarge
                        color: Qt.rgba(0, 0, 0, 0.55)
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.cancelWifiAuth()
                    }

                    Rectangle {
                        id: authCard
                        anchors.centerIn: parent
                        width: Math.min(320, parent.width - 32)
                        implicitHeight: authColumn.implicitHeight + 40
                        radius: Palette.Theme.radiusLarge
                        color: Palette.Theme.surfaceContainerHigh
                        scale: root.authVisible ? 1 : 0.92

                        Behavior on scale {
                            SpatialMotion {}
                        }

                        MouseArea {
                            // Swallows clicks so the scrim behind doesn't
                            // treat interacting with the card as "cancel".
                            anchors.fill: parent
                        }

                        ColumnLayout {
                            id: authColumn
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 20
                            spacing: 14

                            Rectangle {
                                Layout.alignment: Qt.AlignHCenter
                                implicitWidth: 48
                                implicitHeight: 48
                                radius: 24
                                color: authLayer.hasError ? Qt.alpha(Palette.Theme.errorColor, 0.16) : Palette.Theme.accentTonal

                                Behavior on color {
                                    ColorMotion {}
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "wifi_password"
                                    color: authLayer.hasError ? Palette.Theme.errorColor : Palette.Theme.accent
                                    font.family: Palette.Theme.fontIcons
                                    font.pixelSize: Palette.Theme.iconSizeLarge
                                }
                            }

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4

                                Text {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    text: root.authNetwork ? root.authNetwork.name : ""
                                    color: Palette.Theme.textPrimary
                                    font.family: Palette.Theme.fontSans
                                    font.pixelSize: Palette.Theme.fontSizeTitle
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }

                                Text {
                                    Layout.fillWidth: true
                                    horizontalAlignment: Text.AlignHCenter
                                    text: root.authNetwork ? "Enter the password for this " + WifiSecurityType.toString(root.authNetwork.security) + " network" : ""
                                    color: Palette.Theme.textMuted
                                    font.family: Palette.Theme.fontSans
                                    font.pixelSize: Palette.Theme.fontSizeXs
                                    wrapMode: Text.WordWrap
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 44
                                radius: Palette.Theme.radiusMedium
                                color: Palette.Theme.surfaceContainerHighest
                                border.width: authPasswordInput.activeFocus || authLayer.hasError ? 2 : 0
                                border.color: authLayer.hasError ? Palette.Theme.errorColor : Palette.Theme.accent

                                Behavior on border.color {
                                    ColorMotion {}
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 14
                                    anchors.rightMargin: 6
                                    spacing: 10

                                    Text {
                                        text: "lock"
                                        color: Palette.Theme.textMuted
                                        font.family: Palette.Theme.fontIcons
                                        font.pixelSize: Palette.Theme.iconSizeSmall
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true

                                        TextInput {
                                            id: authPasswordInput
                                            anchors.fill: parent
                                            verticalAlignment: TextInput.AlignVCenter
                                            echoMode: authLayer.reveal ? TextInput.Normal : TextInput.Password
                                            color: Palette.Theme.textPrimary
                                            selectionColor: Palette.Theme.accent
                                            selectedTextColor: Palette.Theme.accentText
                                            font.family: Palette.Theme.fontSans
                                            font.pixelSize: Palette.Theme.fontSizeBody
                                            selectByMouse: true
                                            readOnly: root.authBusy
                                            clip: true

                                            Keys.onEscapePressed: root.cancelWifiAuth()
                                            onAccepted: root.submitWifiAuth(text)
                                        }

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: authPasswordInput.text.length === 0
                                            text: "Password"
                                            color: Palette.Theme.textMuted
                                            font: authPasswordInput.font
                                        }
                                    }

                                    IconButton {
                                        icon: authLayer.reveal ? "visibility_off" : "visibility"
                                        implicitWidth: 32
                                        implicitHeight: 32
                                        onClicked: authLayer.reveal = !authLayer.reveal
                                    }
                                }
                            }

                            // Busy, error, or what a valid password looks like.
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                Text {
                                    Layout.alignment: Qt.AlignTop
                                    text: root.authBusy ? "progress_activity" : (authLayer.hasError ? "error" : "info")
                                    color: authLayer.hasError ? Palette.Theme.errorColor : (root.authBusy ? Palette.Theme.accent : Palette.Theme.textMuted)
                                    font.family: Palette.Theme.fontIcons
                                    font.pixelSize: Palette.Theme.iconSizeSmall

                                    RotationAnimator on rotation {
                                        running: root.authBusy
                                        from: 0
                                        to: 360
                                        duration: 900
                                        loops: Animation.Infinite
                                        onRunningChanged: if (!running)
                                            target.rotation = 0
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: root.authBusy ? "Connecting…" : (authLayer.hasError ? root.authError : root.passwordHint(root.authNetwork))
                                    color: authLayer.hasError ? Palette.Theme.errorColor : Palette.Theme.textMuted
                                    font.family: Palette.Theme.fontSans
                                    font.pixelSize: Palette.Theme.fontSizeXs
                                    wrapMode: Text.WordWrap
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                Item {
                                    Layout.fillWidth: true
                                }

                                ActionChip {
                                    label: "Cancel"
                                    chipHeight: 34
                                    horizontalPadding: 32
                                    fontPixelSize: Palette.Theme.fontSizeSmall
                                    onClicked: root.cancelWifiAuth()
                                }

                                ActionChip {
                                    label: root.authBusy ? "Connecting…" : "Connect"
                                    active: true
                                    chipHeight: 34
                                    horizontalPadding: 32
                                    fontPixelSize: Palette.Theme.fontSizeSmall
                                    enabled: authLayer.valid && !root.authBusy
                                    opacity: enabled ? 1 : 0.45
                                    onClicked: root.submitWifiAuth(authPasswordInput.text)

                                    Behavior on opacity {
                                        EffectMotion {}
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
