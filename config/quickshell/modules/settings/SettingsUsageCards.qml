pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../../components/material"
import "../../theme" as Palette

// CPU, memory, disk and temperature in a 2×2 grid, each as a card with a
// ring gauge around its icon and the current figure. The ring turns to the
// warning color when the resource is nearly maxed (temperature: warning
// from 70 °C, error from 85 °C). Disk and temperature come from the
// window's SystemStats, which polls only while this page is open.
GridLayout {
    id: root

    required property var panel
    readonly property var stats: panel.stats

    columns: 2
    columnSpacing: Palette.Theme.spacingSmall
    rowSpacing: Palette.Theme.spacingSmall

    Repeater {
        model: [
            { key: "cpu", icon: "memory", title: "CPU" },
            { key: "ram", icon: "memory_alt", title: "Memory" },
            { key: "disk", icon: "hard_drive", title: "Disk" },
            { key: "temp", icon: "thermostat", title: "Temperature" }
        ]

        delegate: Rectangle {
            id: card

            required property var modelData

            readonly property bool isTemp: modelData.key === "temp"
            readonly property real usage: {
                if (modelData.key === "disk")
                    return root.stats.disk;
                if (isTemp)
                    return root.stats.temperatureFraction;
                return root.panel.level(modelData.key);
            }
            // Each resource its own hue (as on the dashboard); warning and
            // error only when it's actually maxed or hot.
            readonly property color hue: ({
                    cpu: Palette.Theme.blue,
                    ram: Palette.Theme.purple,
                    disk: Palette.Theme.green,
                    temp: Palette.Theme.aqua
                })[modelData.key]
            readonly property color tone: {
                if (isTemp)
                    return root.stats.temperature >= 85 ? Palette.Theme.errorColor : root.stats.temperature >= 70 ? Palette.Theme.warning : hue;
                return usage >= 0.9 ? Palette.Theme.warning : hue;
            }
            readonly property string figure: isTemp ? Math.round(root.stats.temperature) + "°C" : Math.round(usage * 100) + "%"
            readonly property string detail: {
                if (modelData.key === "disk")
                    return root.stats.gib(root.stats.diskUsed) + " of " + root.stats.gib(root.stats.diskTotal) + " GiB";
                if (isTemp)
                    return "CPU package";
                return root.panel.infoFor(modelData.key);
            }

            Layout.fillWidth: true
            Layout.preferredHeight: 88
            radius: Palette.Theme.radiusMedium
            color: Palette.Theme.surfaceContainer

            // Eased copy of `usage` for the ring, so each 2 s sample sweeps
            // rather than jumps.
            property real shownUsage: usage
            Behavior on shownUsage {
                EffectMotion {
                    fast: false
                }
            }
            onShownUsageChanged: ring.requestPaint()
            onToneChanged: ring.requestPaint()

            RowLayout {
                anchors.fill: parent
                anchors.margins: Palette.Theme.spacingLarge
                spacing: 14

                // Ring gauge with the resource's icon in the middle.
                Item {
                    Layout.preferredWidth: 56
                    Layout.preferredHeight: 56

                    Canvas {
                        id: ring
                        anchors.fill: parent

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.reset();
                            var r = width / 2 - 4;
                            var start = -Math.PI / 2;
                            ctx.lineWidth = 6;
                            ctx.lineCap = "round";
                            ctx.strokeStyle = Palette.Theme.surfaceContainerHigh;
                            ctx.beginPath();
                            ctx.arc(width / 2, height / 2, r, 0, 2 * Math.PI);
                            ctx.stroke();
                            var p = Math.max(0, Math.min(1, card.shownUsage));
                            if (p > 0.005) {
                                ctx.strokeStyle = card.tone;
                                ctx.beginPath();
                                ctx.arc(width / 2, height / 2, r, start, start + p * 2 * Math.PI);
                                ctx.stroke();
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: card.modelData.icon
                        color: card.tone
                        font.family: Palette.Theme.fontIcons
                        font.weight: Palette.Theme.iconWeight
                        font.pixelSize: Palette.Theme.iconSizeLarge

                        Behavior on color {
                            ColorMotion {}
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 0

                    Text {
                        text: card.modelData.title
                        color: Palette.Theme.textMuted
                        font.family: Palette.Theme.fontSans
                        font.pixelSize: Palette.Theme.fontSizeXs
                        font.weight: Font.DemiBold
                        font.letterSpacing: 0.8
                        font.capitalization: Font.AllUppercase
                    }

                    Text {
                        text: card.figure
                        color: Palette.Theme.textPrimary
                        font.family: Palette.Theme.fontSans
                        font.pixelSize: Palette.Theme.fontSizeDisplay
                        font.weight: Font.DemiBold
                    }

                    Text {
                        Layout.fillWidth: true
                        text: card.detail
                        color: Palette.Theme.textSecondary
                        font.family: Palette.Theme.fontSans
                        font.pixelSize: Palette.Theme.fontSizeXs
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
