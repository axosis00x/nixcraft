import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import "../../components/material"
import "../../theme" as Palette

// Left-edge bar in the spirit of Caelestia's: one solid strip fused to the
// screen edge (with concave fillets where it meets the top and bottom
// edges), holding grouped pills — launcher and workspaces at the top, the
// focused window's icon and title running down the middle, and tray,
// status, clock and power at the bottom.
Item {
    id: root

    required property var bar
    // Width of the solid strip; the fillets hang just outside it.
    property real thickness: 44
    property real filletSize: 8

    readonly property real pillWidth: thickness - 12

    // ── strip ───────────────────────────────────────────────────────
    Rectangle {
        id: strip
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: root.thickness
        color: Palette.Theme.bg
    }

    RoundCorner {
        anchors.left: strip.right
        anchors.top: parent.top
        corner: "topLeft"
        size: root.filletSize
        color: strip.color
    }

    RoundCorner {
        anchors.left: strip.right
        anchors.bottom: parent.bottom
        corner: "bottomLeft"
        size: root.filletSize
        color: strip.color
    }

    // ── top: launcher + workspaces ──────────────────────────────────
    ColumnLayout {
        id: topGroup
        anchors.top: strip.top
        anchors.topMargin: 8
        anchors.horizontalCenter: strip.horizontalCenter
        spacing: 8

        BarButton {
            Layout.alignment: Qt.AlignHCenter
            onClicked: root.bar.toggleLauncher()

            Image {
                anchors.centerIn: parent
                width: 18
                height: 18
                source: Qt.resolvedUrl("../../assets/icons/nix-logo.png")
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
            }
        }

        Pill {
            Layout.alignment: Qt.AlignHCenter
            implicitHeight: workspaces.implicitHeight + 20

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.bar.workspacesService)
                        root.bar.workspacesService.step(1);
                }
            }

            Workspaces {
                id: workspaces
                anchors.centerIn: parent
                vertical: true
                service: root.bar.workspacesService
            }
        }
    }

    // ── middle: focused window ──────────────────────────────────────
    // Lives in whatever space the top and bottom groups leave, so a long
    // title elides instead of running into them.
    Item {
        id: middle
        anchors.top: topGroup.bottom
        anchors.bottom: bottomGroup.top
        anchors.left: strip.left
        anchors.right: strip.right
        anchors.topMargin: 12
        anchors.bottomMargin: 12

        TextMetrics {
            id: titleMetrics
            text: title.text
            font: title.font
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 10
            visible: middle.height > 40

            Item {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 20
                implicitHeight: 20

                IconImage {
                    anchors.centerIn: parent
                    implicitSize: 18
                    source: root.bar.iconForClass(root.bar.appClass)
                    visible: root.bar.appClass !== "" && source !== ""
                    smooth: true
                    mipmap: true
                }

                Text {
                    anchors.centerIn: parent
                    visible: root.bar.appClass === ""
                    text: "desktop_windows"
                    color: Palette.Theme.textMuted
                    font.family: Palette.Theme.fontIcons
                    font.pixelSize: Palette.Theme.iconSize
                }
            }

            // Title reads top-to-bottom, rotated a quarter turn; the
            // wrapper reports the rotated footprint to the layout.
            Item {
                id: titleBox
                readonly property real maxLength: Math.max(0, middle.height - 30)
                readonly property real length: Math.min(Math.ceil(titleMetrics.advanceWidth) + 2, maxLength)

                Layout.alignment: Qt.AlignHCenter
                implicitWidth: title.height
                implicitHeight: length

                Text {
                    id: title
                    anchors.centerIn: parent
                    width: titleBox.length
                    rotation: 90
                    text: root.bar.appTitle || "Desktop"
                    color: Palette.Theme.textSecondary
                    font.family: Palette.Theme.fontSans
                    font.pixelSize: Palette.Theme.fontSizeSmall
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }
            }
        }
    }

    // ── bottom: tray, status, clock, power ──────────────────────────
    ColumnLayout {
        id: bottomGroup
        anchors.bottom: strip.bottom
        anchors.bottomMargin: 8
        anchors.horizontalCenter: strip.horizontalCenter
        spacing: 8

        Pill {
            Layout.alignment: Qt.AlignHCenter
            visible: tray.implicitHeight > 0
            implicitHeight: tray.implicitHeight + 20

            Tray {
                id: tray
                anchors.centerIn: parent
                parentWindow: root.bar
                vertical: true
            }
        }

        // Network, Bluetooth and battery; opens the control center.
        Pill {
            id: status
            Layout.alignment: Qt.AlignHCenter
            implicitHeight: statusColumn.implicitHeight + 20

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
            readonly property string networkIcon: {
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
            readonly property bool bluetoothOn: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.enabled : false

            StateLayer {
                radius: parent.radius
                hovered: statusMouse.containsMouse
                pressed: statusMouse.pressed
            }

            MouseArea {
                id: statusMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.bar.toggleControlCenter()
            }

            ColumnLayout {
                id: statusColumn
                anchors.centerIn: parent
                spacing: 10

                StatusIcon {
                    text: status.networkIcon
                    dim: !status.wired && status.wifiSignal < 0
                }

                StatusIcon {
                    text: status.bluetoothOn ? "bluetooth" : "bluetooth_disabled"
                    dim: !status.bluetoothOn
                }

                Battery {
                    Layout.alignment: Qt.AlignHCenter
                    visible: root.bar.batteryAvailable
                    vertical: true
                    showPercent: false
                    bar: root.bar
                }
            }
        }

        // Stacked clock; opens the calendar.
        Pill {
            Layout.alignment: Qt.AlignHCenter
            implicitHeight: clockColumn.implicitHeight + 20

            SystemClock {
                id: clock
                precision: SystemClock.Minutes
            }

            StateLayer {
                radius: parent.radius
                hovered: clockMouse.containsMouse
                pressed: clockMouse.pressed
            }

            MouseArea {
                id: clockMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Quickshell.execDetached(["quickshell", "ipc", "call", "calendar", "toggle"])
            }

            ColumnLayout {
                id: clockColumn
                anchors.centerIn: parent
                spacing: 0

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.bottomMargin: 4
                    text: "schedule"
                    color: Palette.Theme.accent
                    font.family: Palette.Theme.fontIcons
                    font.pixelSize: Palette.Theme.iconSizeSmall
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDateTime(clock.date, "hh")
                    color: Palette.Theme.textPrimary
                    font.family: Palette.Theme.fontSans
                    font.pixelSize: Palette.Theme.fontSizeBody
                    font.weight: Font.DemiBold
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Qt.formatDateTime(clock.date, "mm")
                    color: Palette.Theme.textPrimary
                    font.family: Palette.Theme.fontSans
                    font.pixelSize: Palette.Theme.fontSizeBody
                    font.weight: Font.DemiBold
                }
            }
        }

        BarButton {
            Layout.alignment: Qt.AlignHCenter
            onClicked: Quickshell.execDetached(["quickshell", "ipc", "call", "settings", "toggle"])

            Text {
                anchors.centerIn: parent
                text: "settings"
                color: Palette.Theme.textSecondary
                font.family: Palette.Theme.fontIcons
                font.pixelSize: Palette.Theme.iconSize
            }
        }

        BarButton {
            Layout.alignment: Qt.AlignHCenter
            onClicked: {
                if (root.bar.powerMenu && typeof root.bar.powerMenu.togglePowerMenu === "function")
                    root.bar.powerMenu.togglePowerMenu();
            }

            Text {
                anchors.centerIn: parent
                text: "power_settings_new"
                color: Palette.Theme.errorColor
                font.family: Palette.Theme.fontIcons
                font.pixelSize: Palette.Theme.iconSize
            }
        }
    }

    // A grouped section: the same capsule the horizontal bar uses
    // (BarSection — theme radius and surface tint), one step lighter so it
    // reads against the solid strip.
    component Pill: BarSection {
        implicitWidth: root.pillWidth
        color: Palette.Theme.surfaceContainerHigh
    }

    // A round icon button sitting directly on the strip.
    component BarButton: Item {
        id: button

        signal clicked

        implicitWidth: root.pillWidth
        implicitHeight: root.pillWidth

        scale: buttonMouse.pressed ? 0.88 : 1
        Behavior on scale {
            SpatialMotion {
                fast: true
                bouncy: true
            }
        }

        StateLayer {
            radius: Palette.Theme.radiusSmall
            hovered: buttonMouse.containsMouse
            pressed: buttonMouse.pressed
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }

    component StatusIcon: Text {
        property bool dim: false

        Layout.alignment: Qt.AlignHCenter
        color: dim ? Palette.Theme.textMuted : Palette.Theme.textPrimary
        font.family: Palette.Theme.fontIcons
        font.pixelSize: Palette.Theme.iconSizeSmall

        Behavior on color {
            ColorMotion {}
        }
    }
}
