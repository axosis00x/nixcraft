import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../components/material"
import "../../services"
import "../../services/weather"
import "../../theme" as Palette

// The dashboard's first tab, kept minimal: who and when on top, the
// calendar and system gauges, and what's playing.
Item {
    id: root

    // The media panel, whose player choice and cached cover art this reuses.
    property var media: null
    property var stats: null
    // Refreshes uptime while the tab is on screen.
    property bool active: false

    implicitHeight: grid.implicitHeight + 22

    // ── data ───────────────────────────────────────────────────────
    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    readonly property var weather: WeatherService

    // Back to the current month each time the dashboard opens.
    function reset() {
        calendar.reset();
    }

    property string fullName: ""
    property string uptime: ""

    Process {
        id: whoami
        running: true
        command: ["sh", "-c", "getent passwd \"$USER\" | cut -d: -f5 | cut -d, -f1"]
        stdout: StdioCollector {
            onStreamFinished: root.fullName = text.trim()
        }
    }

    Process {
        id: uptimeRead
        command: ["cat", "/proc/uptime"]
        stdout: StdioCollector {
            onStreamFinished: {
                var s = Math.floor(Number(text.split(" ")[0]) || 0);
                var d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
                // Short, so it fits the card: "up 2h 14m", "up 3d 5h".
                root.uptime = "up " + (d > 0 ? d + "d " + h + "h" : h > 0 ? h + "h " + m + "m" : m + "m");
            }
        }
    }

    Timer {
        interval: 60000
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: uptimeRead.running = true
    }

    // Keep the progress line moving while a track plays.
    Timer {
        interval: 1000
        running: root.active && root.media && root.media.hasPlayer && root.media.player.isPlaying
        repeat: true
        onTriggered: root.media.player.positionChanged()
    }

    readonly property string greeting: {
        var h = clock.date.getHours();
        return h < 5 ? "Good night" : h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening";
    }

    // ── layout ─────────────────────────────────────────────────────
    // A plain header (you on the left, the time on the right), then the
    // calendar beside the system gauges, then a slim now-playing strip.
    ColumnLayout {
        id: grid
        anchors.fill: parent
        // One even gap all round, matching the cards' concentric corners.
        anchors.margins: 10
        anchors.topMargin: 12
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            Layout.rightMargin: 4
            spacing: 12

            Avatar {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: root.fullName || Quickshell.env("USER")
                    color: Palette.Theme.textPrimary
                    font.family: Palette.Theme.fontSans
                    font.pixelSize: Palette.Theme.fontSizeTitle
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: root.uptime
                    color: Palette.Theme.textMuted
                    font.family: Palette.Theme.fontSans
                    font.pixelSize: Palette.Theme.fontSizeXs
                    elide: Text.ElideRight
                }
            }

            ColumnLayout {
                spacing: 0

                Text {
                    Layout.alignment: Qt.AlignRight
                    text: Qt.formatDateTime(clock.date, "hh:mm")
                    color: Palette.Theme.textPrimary
                    font.family: Palette.Theme.fontSans
                    font.pixelSize: Palette.Theme.fontSizeDisplay
                    font.weight: Font.Bold
                }

                Text {
                    Layout.alignment: Qt.AlignRight
                    text: Qt.formatDateTime(clock.date, "ddd, d MMM") + (weather.available ? "  ·  " + weather.tempC + "°" : "")
                    color: Palette.Theme.textMuted
                    font.family: Palette.Theme.fontSans
                    font.pixelSize: Palette.Theme.fontSizeXs
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            DashCard {
                Layout.fillWidth: true
                Layout.preferredWidth: 3
                Layout.preferredHeight: 196

                MiniCalendar {
                    id: calendar
                    anchors.fill: parent
                    anchors.margins: 12
                }
            }

            DashCard {
                Layout.fillWidth: true
                Layout.preferredWidth: 2
                Layout.preferredHeight: 196

                GridLayout {
                    anchors.centerIn: parent
                    columns: 2
                    columnSpacing: 14
                    rowSpacing: 8

                    StatRing {
                        size: 44
                        thickness: 4
                        value: root.stats ? root.stats.cpu : 0
                        label: "CPU"
                        accent: Palette.Theme.blue
                    }
                    StatRing {
                        size: 44
                        thickness: 4
                        value: root.stats ? root.stats.memory : 0
                        label: "RAM"
                        accent: Palette.Theme.purple
                    }
                    StatRing {
                        size: 44
                        thickness: 4
                        value: root.stats ? root.stats.disk : 0
                        label: "Disk"
                        accent: Palette.Theme.green
                    }
                    StatRing {
                        size: 44
                        thickness: 4
                        value: root.stats ? root.stats.temperatureFraction : 0
                        text: root.stats ? Math.round(root.stats.temperature) + "°" : "--"
                        label: "Temp"
                        accent: root.stats && root.stats.temperature >= 85 ? Palette.Theme.errorColor : root.stats && root.stats.temperature >= 70 ? Palette.Theme.warning : Palette.Theme.aqua
                    }
                }
            }
        }

        // Now playing, in one row.
        DashCard {
            id: nowPlaying
            Layout.fillWidth: true
            Layout.preferredHeight: 68

            readonly property var player: root.media ? root.media.player : null
            readonly property bool hasPlayer: root.media ? root.media.hasPlayer : false

            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 12
                visible: nowPlaying.hasPlayer

                CoverArt {
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    radius: Palette.Theme.radiusSmall
                    source: root.media ? root.media.artSource : ""
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0

                    Text {
                        Layout.fillWidth: true
                        text: nowPlaying.player ? (nowPlaying.player.trackTitle || "Unknown track") : ""
                        color: Palette.Theme.textPrimary
                        font.family: Palette.Theme.fontSans
                        font.pixelSize: Palette.Theme.fontSizeBody
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: nowPlaying.player ? (nowPlaying.player.trackArtist || "") : ""
                        color: Palette.Theme.textMuted
                        font.family: Palette.Theme.fontSans
                        font.pixelSize: Palette.Theme.fontSizeXs
                        elide: Text.ElideRight
                    }
                }

                MediaControls {
                    player: nowPlaying.player
                    compact: true
                }
            }

            Row {
                anchors.centerIn: parent
                visible: !nowPlaying.hasPlayer
                spacing: 8

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "music_off"
                    color: Palette.Theme.textMuted
                    font.family: Palette.Theme.fontIcons
                    font.weight: Palette.Theme.iconWeight
                    font.pixelSize: Palette.Theme.iconSize
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Nothing playing"
                    color: Palette.Theme.textMuted
                    font.family: Palette.Theme.fontSans
                    font.pixelSize: Palette.Theme.fontSizeSmall
                }
            }
        }
    }
}
