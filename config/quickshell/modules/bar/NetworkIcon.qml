import Quickshell.Networking
import QtQuick
import "../../theme" as Palette

// Network status as a Material Symbol: wired, Wi-Fi strength, or off.
// Reads Quickshell's native Networking module (no polling).
Text {
    id: root

    readonly property var wifiDevice: {
        var list = Networking.devices.values;
        for (var i = 0; i < list.length; i++) {
            if (list[i].type === DeviceType.Wifi)
                return list[i];
        }
        return null;
    }
    readonly property bool wired: {
        var list = Networking.devices.values;
        for (var i = 0; i < list.length; i++) {
            if (list[i].type === DeviceType.Wired && list[i].connected)
                return true;
        }
        return false;
    }
    readonly property real wifiSignal: {
        if (!wifiDevice || !wifiDevice.connected)
            return -1;
        var nets = wifiDevice.networks.values;
        for (var i = 0; i < nets.length; i++) {
            if (nets[i].connected)
                return nets[i].signalStrength;
        }
        return -1;
    }
    readonly property bool connected: wired || wifiSignal >= 0

    text: {
        if (wired)
            return "lan";
        if (!Networking.wifiEnabled)
            return "wifi_off";
        if (wifiSignal < 0)
            return "signal_wifi_0_bar";
        if (wifiSignal > 0.66)
            return "wifi";
        if (wifiSignal > 0.33)
            return "wifi_2_bar";
        return "wifi_1_bar";
    }
    color: connected ? Palette.Theme.textPrimary : Palette.Theme.textMuted
    font.family: Palette.Theme.fontIcons
    font.pixelSize: Palette.Theme.iconSizeSmall

    Behavior on color {
        ColorAnimation {
            duration: Palette.Theme.effectFast
        }
    }
}
