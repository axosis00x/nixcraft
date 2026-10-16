import QtQuick
import "../../components/material"
import "../../theme" as Palette

// Previous / play-pause / next for an MPRIS player. The play button is an
// accent circle that squeezes on press and rounds out while playing.
Row {
    id: root

    property var player: null
    // Smaller buttons for the overview card.
    property bool compact: false

    readonly property real playSize: compact ? 36 : 52
    readonly property real sideSize: compact ? 30 : 40
    readonly property bool playing: player ? player.isPlaying : false

    spacing: compact ? 6 : 14

    IconButton {
        anchors.verticalCenter: parent.verticalCenter
        icon: "skip_previous"
        implicitWidth: root.sideSize
        implicitHeight: root.sideSize
        iconSize: root.compact ? Palette.Theme.iconSize : Palette.Theme.iconSizeLarge
        iconColor: Palette.Theme.textPrimary
        enabled: root.player ? root.player.canGoPrevious : false
        opacity: enabled ? 1 : 0.35
        onClicked: root.player.previous()
    }

    Rectangle {
        id: play
        anchors.verticalCenter: parent.verticalCenter
        width: root.playSize
        height: root.playSize
        radius: Math.min(height / 2, root.playing ? Palette.Theme.radiusLarge : Palette.Theme.radiusMedium)
        color: Palette.Theme.accent
        scale: playMouse.pressed ? 0.9 : 1

        Behavior on radius {
            SpatialMotion {}
        }
        Behavior on scale {
            SpatialMotion {
                fast: true
                bouncy: true
            }
        }

        StateLayer {
            radius: parent.radius
            tone: Palette.Theme.accentText
            hovered: playMouse.containsMouse
            pressed: playMouse.pressed
        }

        Text {
            anchors.centerIn: parent
            text: root.playing ? "pause" : "play_arrow"
            color: Palette.Theme.accentText
            font.family: Palette.Theme.fontIcons
            font.weight: Palette.Theme.iconWeight
            font.pixelSize: root.compact ? Palette.Theme.iconSizeLarge : Palette.Theme.iconSizeLarge * 1.3
        }

        MouseArea {
            id: playMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: root.player ? root.player.canTogglePlaying : false
            onClicked: root.player.togglePlaying()
        }
    }

    IconButton {
        anchors.verticalCenter: parent.verticalCenter
        icon: "skip_next"
        implicitWidth: root.sideSize
        implicitHeight: root.sideSize
        iconSize: root.compact ? Palette.Theme.iconSize : Palette.Theme.iconSizeLarge
        iconColor: Palette.Theme.textPrimary
        enabled: root.player ? root.player.canGoNext : false
        opacity: enabled ? 1 : 0.35
        onClicked: root.player.next()
    }
}
