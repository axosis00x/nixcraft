import QtQuick
import QtQuick.Layouts
import "../../theme" as Palette

// The dashboard's performance tab: large live gauges for CPU, memory, disk
// and temperature, each with the numbers behind it.
Item {
    id: root

    property var stats: null

    implicitHeight: 184

    DashCard {
        anchors.fill: parent
        anchors.margins: 10

        RowLayout {
            anchors.centerIn: parent
            spacing: 16

            StatRing {
                size: 72
                thickness: 6
                value: root.stats ? root.stats.cpu : 0
                label: "CPU"
                accent: Palette.Theme.blue
                caption: "processor load"
            }

            StatRing {
                size: 72
                thickness: 6
                value: root.stats ? root.stats.memory : 0
                label: "Memory"
                accent: Palette.Theme.purple
                caption: root.stats ? root.stats.gib(root.stats.memoryUsed) + " / " + root.stats.gib(root.stats.memoryTotal) + " GiB" : ""
            }

            StatRing {
                size: 72
                thickness: 6
                value: root.stats ? root.stats.disk : 0
                label: "Disk"
                accent: Palette.Theme.green
                caption: root.stats ? root.stats.gib(root.stats.diskUsed) + " / " + root.stats.gib(root.stats.diskTotal) + " GiB" : ""
            }

            StatRing {
                size: 72
                thickness: 6
                value: root.stats ? root.stats.temperatureFraction : 0
                text: root.stats ? Math.round(root.stats.temperature) + "°C" : "--"
                // Warm colours only when it actually runs hot.
                accent: root.stats && root.stats.temperature >= 85 ? Palette.Theme.errorColor : root.stats && root.stats.temperature >= 70 ? Palette.Theme.warning : Palette.Theme.aqua
                label: "Temperature"
                caption: "CPU package"
            }
        }
    }
}
