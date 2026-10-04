import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../theme" as Palette
import "../../components/material"

// Notch-embedded media player panel. Follows the same open/close signal
// contract as Clipboard and PowerMenu so CenterOverlay can manage it uniformly.
Item {
    id: root

    signal aboutToOpen
    signal aboutToClose

    visible: false
    focus: true

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            event.accepted = true;
            close(false);
        }
    }

    onVisibleChanged: {
        if (visible) {
            forceActiveFocus();
        }
    }

    implicitWidth: 460
    implicitHeight: body.implicitHeight + 32

    // ── MPRIS player selection ────────────────────────────────────────────────
    // Follows whatever is playing, unless a player was picked with the
    // switcher chip (pinned by D-Bus name until it goes away).
    property string pinnedPlayer: ""
    property var player: {
        var list = Mpris.players.values;
        if (list.length === 0)
            return null;
        if (pinnedPlayer !== "") {
            for (var p = 0; p < list.length; p++) {
                if (list[p].dbusName === pinnedPlayer)
                    return list[p];
            }
        }
        for (var i = 0; i < list.length; i++) {
            if (list[i].isPlaying)
                return list[i];
        }
        return list[0];
    }
    readonly property int playerCount: Mpris.players.values.length

    function cyclePlayer() {
        var list = Mpris.players.values;
        if (list.length < 2)
            return;
        var i = list.indexOf(player);
        pinnedPlayer = list[(i + 1) % list.length].dbusName;
    }

    property bool hasPlayer: player !== null

    property real progress: {
        if (!player || !player.length || player.length <= 0)
            return 0;
        return Math.min(1, Math.max(0, player.position / player.length));
    }

    // Poll position while playing so the progress bar animates.
    Timer {
        interval: 500
        running: root.hasPlayer && root.player !== null && root.player.isPlaying && root.visible
        repeat: true
        onTriggered: if (root.player) root.player.positionChanged()
    }

    function formatTime(seconds) {
        if (!seconds || seconds < 0 || !isFinite(seconds))
            return "0:00";
        var total = Math.floor(seconds);
        var sec = total % 60;
        return Math.floor(total / 60) + ":" + (sec < 10 ? "0" : "") + sec;
    }

    // ── Public API ────────────────────────────────────────────────────────────
    function open() {
        visible = true;
        root.aboutToOpen();
    }

    function close(immediately) {
        root.aboutToClose();
        if (immediately)
            visible = false;
        else
            hideTimer.restart();
    }

    function toggleMediaPanel() {
        if (visible)
            close(false);
        else
            open();
    }

    Timer {
        id: hideTimer
        interval: 200
        onTriggered: root.visible = false
    }

    // Changes whenever the track does; drives the track-change motion.
    readonly property string trackKey: player ? (player.trackTitle || "") + "\u0001" + (player.trackArtist || "") : ""
    onTrackKeyChanged: trackChange.restart()

    // ── Backdrop: the cover, heavily blurred and dimmed ──────────────────────
    // Gives each track its own mood. The blurred cover is drawn larger than
    // the panel (by `bleed` on every side) so the blur has real image to
    // sample at the edges instead of fading to a dark rim, then masked back
    // to the panel's exact silhouette: flat top, the notch's 20px bottom
    // corners.
    Item {
        id: backdrop
        anchors.fill: parent
        opacity: artImg.status === Image.Ready ? 1 : 0

        readonly property real bleed: 48

        Behavior on opacity {
            EffectMotion {
                fast: false
            }
        }

        Image {
            id: backdropImg
            anchors.fill: parent
            anchors.margins: -backdrop.bleed
            source: artImg.source
            sourceSize: Qt.size(96, 96)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
        }

        // Mask covering the oversized effect, opaque only over the panel.
        Item {
            id: backdropMask
            anchors.fill: backdropImg
            visible: false
            layer.enabled: true
            layer.smooth: true

            Rectangle {
                anchors.fill: parent
                anchors.margins: backdrop.bleed
                bottomLeftRadius: 20
                bottomRightRadius: 20
                antialiasing: true
            }
        }

        MultiEffect {
            anchors.fill: backdropImg
            source: backdropImg
            autoPaddingEnabled: false
            blurEnabled: true
            blur: 1
            blurMax: 48
            saturation: 0.2
            brightness: -0.1
            opacity: 0.3
            maskEnabled: true
            maskSource: backdropMask
            // Soft mask edge so the curve blends into the notch outline.
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
        }
    }

    // ── Content ───────────────────────────────────────────────────────────────
    // Art and track info on top, then elapsed · wave · total, then a centered
    // row of controls. Material 3 Expressive motion throughout: springy
    // presses, a cookie-shaped play button that turns while playing, icons
    // that nudge toward where they send you, and a wave that ripples while
    // playing and settles flat when paused.
    RowLayout {
        id: body
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        // Album art: a square as tall as the column beside it. A
        // ClippingRectangle (unlike clip: true) clips to its rounded corners.
        ClippingRectangle {
            id: art
            Layout.preferredWidth: column.implicitHeight
            Layout.preferredHeight: column.implicitHeight
            Layout.alignment: Qt.AlignVCenter
            radius: 4
            color: Palette.Theme.surfaceContainerHigh

            Image {
                id: artImg
                anchors.fill: parent
                source: root.player ? root.player.trackArtUrl : ""
                sourceSize: Qt.size(240, 240)
                fillMode: Image.PreserveAspectCrop
                smooth: true
                asynchronous: true
                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity {
                    EffectMotion {
                        fast: false
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                visible: artImg.status !== Image.Ready
                text: "music_note"
                font.family: Palette.Theme.fontIcons
                font.pixelSize: 34
                color: Palette.Theme.textMuted
            }
        }

        // Title, artist, progress and controls share one left edge.
        ColumnLayout {
            id: column
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 6

            ColumnLayout {
                id: info
                Layout.fillWidth: true
                spacing: 2

                transform: Translate {
                    id: infoShift
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // Long titles scroll back and forth instead of eliding.
                    Item {
                        id: titleClip
                        Layout.fillWidth: true
                        implicitHeight: titleText.implicitHeight
                        clip: true

                        readonly property real overflow: Math.max(0, titleText.implicitWidth - width)
                        onOverflowChanged: {
                            titleText.x = 0;
                            marquee.restart();
                        }

                        Text {
                            id: titleText
                            text: root.player ? (root.player.trackTitle || "Unknown Title") : "Nothing playing"
                            color: Palette.Theme.textTitle
                            font.family: Palette.Theme.fontMono
                            font.pixelSize: Palette.Theme.fontSizeBody
                            font.weight: Font.DemiBold
                        }

                        SequentialAnimation {
                            id: marquee
                            running: root.visible && titleClip.overflow > 0
                            loops: Animation.Infinite
                            PauseAnimation {
                                duration: 2000
                            }
                            NumberAnimation {
                                target: titleText
                                property: "x"
                                to: -titleClip.overflow
                                duration: Math.max(800, titleClip.overflow * 35)
                                easing.type: Easing.InOutSine
                            }
                            PauseAnimation {
                                duration: 1500
                            }
                            NumberAnimation {
                                target: titleText
                                property: "x"
                                to: 0
                                duration: Palette.Theme.motionSlow
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    // Which player this is; with several, click to switch.
                    Rectangle {
                        id: playerChip
                        visible: root.hasPlayer
                        implicitWidth: chipRow.implicitWidth + 16
                        implicitHeight: 22
                        radius: height / 2
                        color: Qt.alpha(Palette.Theme.textPrimary, 0.08)
                        scale: chipMouse.pressed ? 0.92 : 1

                        Behavior on scale {
                            SpatialMotion {
                                fast: true
                                bouncy: true
                            }
                        }

                        StateLayer {
                            radius: parent.radius
                            hovered: chipMouse.containsMouse && root.playerCount > 1
                            pressed: chipMouse.pressed && root.playerCount > 1
                        }

                        Row {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: 5

                            IconImage {
                                id: chipIcon
                                anchors.verticalCenter: parent.verticalCenter
                                implicitSize: 13
                                source: root.player && root.player.desktopEntry ? Quickshell.iconPath(root.player.desktopEntry, true) : ""
                                visible: source !== "" && status === Image.Ready
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.player ? (root.player.identity || "Player") : ""
                                color: Palette.Theme.textSecondary
                                font.family: Palette.Theme.fontSans
                                font.pixelSize: Palette.Theme.fontSizeXs
                                font.weight: Font.Medium
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: root.playerCount > 1
                                text: "unfold_more"
                                color: Palette.Theme.textMuted
                                font.family: Palette.Theme.fontIcons
                                font.pixelSize: 13
                            }
                        }

                        MouseArea {
                            id: chipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: root.playerCount > 1
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.cyclePlayer()
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: root.player ? (root.player.trackArtist || "") : ""
                    visible: text !== ""
                    color: Palette.Theme.textSecondary
                    font.family: Palette.Theme.fontMono
                    font.pixelSize: Palette.Theme.fontSizeSmall
                    elide: Text.ElideRight
                }
            }

            // Elapsed · wave · total
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Text {
                    text: root.formatTime(waveArea.dragging ? waveArea.dragProgress * (root.player ? root.player.length : 0) : (root.player ? root.player.position : 0))
                    color: Palette.Theme.textMuted
                    font.family: Palette.Theme.fontMono
                    font.pixelSize: Palette.Theme.fontSizeXs
                }

                Item {
                    id: waveArea
                    Layout.fillWidth: true
                    implicitHeight: 22

                    property bool dragging: false
                    property bool hovering: false
                    property real dragProgress: 0
                    readonly property bool canSeek: root.hasPlayer && root.player.canSeek

                    Canvas {
                        id: wave
                        anchors.fill: parent

                        readonly property real wavelength: 18
                        // Ripples while playing and settles flat when paused.
                        property real amplitude: root.hasPlayer && root.player.isPlaying && !waveArea.dragging ? 2.6 : 0
                        Behavior on amplitude {
                            SpatialMotion {}
                        }
                        property real phase: 0
                        NumberAnimation on phase {
                            from: 0
                            to: wave.wavelength
                            duration: 1100
                            loops: Animation.Infinite
                            running: root.visible && wave.amplitude > 0.01
                        }
                        // The handle grows while hovered or dragged.
                        property real handleHalf: waveArea.dragging ? 10 : (waveArea.hovering ? 9 : 7)
                        Behavior on handleHalf {
                            SpatialMotion {
                                fast: true
                                bouncy: true
                            }
                        }

                        property real shown: waveArea.dragging ? waveArea.dragProgress : root.progress
                        Behavior on shown {
                            enabled: !waveArea.dragging
                            EffectMotion {
                                fast: false
                            }
                        }

                        onPhaseChanged: requestPaint()
                        onAmplitudeChanged: requestPaint()
                        onHandleHalfChanged: requestPaint()
                        onShownChanged: requestPaint()
                        onWidthChanged: requestPaint()
                        onVisibleChanged: if (visible)
                            requestPaint()

                        readonly property color activeColor: Palette.Theme.accent
                        onActiveColorChanged: requestPaint()
                        readonly property color trackColor: Qt.alpha(Palette.Theme.textPrimary, 0.22)

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.reset();
                            var w = width, mid = height / 2, gap = 4;
                            var splitX = 2 + (w - 4) * shown;
                            ctx.lineCap = "round";
                            ctx.lineJoin = "round";

                            if (splitX - gap > 2) {
                                ctx.strokeStyle = activeColor;
                                ctx.lineWidth = 3.2;
                                ctx.beginPath();
                                for (var x = 2; x <= splitX - gap; x++) {
                                    var y = mid + Math.sin(((x + phase) / wavelength) * Math.PI * 2) * amplitude;
                                    if (x === 2)
                                        ctx.moveTo(x, y);
                                    else
                                        ctx.lineTo(x, y);
                                }
                                ctx.stroke();
                            }
                            if (splitX + gap < w - 2) {
                                ctx.strokeStyle = trackColor;
                                ctx.lineWidth = 3.2;
                                ctx.beginPath();
                                ctx.moveTo(splitX + gap, mid);
                                ctx.lineTo(w - 2, mid);
                                ctx.stroke();
                            }

                            ctx.strokeStyle = activeColor;
                            ctx.lineWidth = 4;
                            ctx.beginPath();
                            ctx.moveTo(splitX, mid - handleHalf);
                            ctx.lineTo(splitX, mid + handleHalf);
                            ctx.stroke();
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.topMargin: -6
                        anchors.bottomMargin: -6
                        hoverEnabled: true
                        enabled: waveArea.canSeek
                        preventStealing: true
                        cursorShape: waveArea.canSeek ? Qt.PointingHandCursor : Qt.ArrowCursor

                        function fraction(mx) {
                            return Math.min(1, Math.max(0, mx / width));
                        }

                        onEntered: waveArea.hovering = true
                        onExited: waveArea.hovering = false
                        onPressed: mouse => {
                            waveArea.dragProgress = fraction(mouse.x);
                            waveArea.dragging = true;
                        }
                        onPositionChanged: mouse => {
                            if (waveArea.dragging)
                                waveArea.dragProgress = fraction(mouse.x);
                        }
                        onReleased: mouse => {
                            if (root.player && root.player.length > 0)
                                root.player.position = fraction(mouse.x) * root.player.length;
                            waveArea.dragging = false;
                        }
                        onCanceled: waveArea.dragging = false
                        // Scroll to nudge ±5 s.
                        onWheel: wheel => {
                            if (!root.player || !(root.player.length > 0))
                                return;
                            var step = wheel.angleDelta.y > 0 ? 5 : -5;
                            root.player.position = Math.max(0, Math.min(root.player.length - 1, root.player.position + step));
                        }
                    }
                }

                Text {
                    text: root.formatTime(root.player ? root.player.length : 0)
                    color: Palette.Theme.textMuted
                    font.family: Palette.Theme.fontMono
                    font.pixelSize: Palette.Theme.fontSizeXs
                }
            }

            // Controls
            RowLayout {
                Layout.alignment: Qt.AlignLeft
                Layout.topMargin: 2
                spacing: 6

                ToggleControl {
                    icon: "shuffle"
                    supported: root.hasPlayer && root.player.shuffleSupported
                    on: supported && root.player.shuffle
                    onClicked: root.player.shuffle = !root.player.shuffle
                }

                SkipControl {
                    icon: "skip_previous"
                    direction: -1
                    enabled: root.hasPlayer && root.player.canGoPrevious
                    onClicked: root.player.previous()
                }

                // Play / pause: a cookie that slowly turns while playing.
                Item {
                    id: playButton
                    implicitWidth: 36
                    implicitHeight: 36
                    readonly property bool playing: root.hasPlayer && root.player.isPlaying

                    scale: playMouse.pressed ? 0.88 : 1
                    Behavior on scale {
                        SpatialMotion {
                            fast: true
                            bouncy: true
                        }
                    }

                    CookieShape {
                        id: cookie
                        anchors.fill: parent
                        color: Palette.Theme.accent
                        lobes: 8
                        amplitude: 0.07

                        // Pauses (rather than stops) with playback, so it
                        // resumes from the angle it stopped at.
                        NumberAnimation on rotation {
                            from: 0
                            to: 360
                            duration: 12000
                            loops: Animation.Infinite
                            running: root.visible
                            paused: running && !playButton.playing
                        }
                    }

                    Text {
                        id: playIcon
                        anchors.centerIn: parent
                        text: playButton.playing ? "pause" : "play_arrow"
                        color: Palette.Theme.accentText
                        font.family: Palette.Theme.fontIcons
                        font.pixelSize: Palette.Theme.iconSizeLarge
                        // Pops when it switches between play and pause.
                        onTextChanged: iconPop.restart()

                        SequentialAnimation {
                            id: iconPop
                            NumberAnimation {
                                target: playIcon
                                property: "scale"
                                to: 0.6
                                duration: Palette.Theme.effectFast
                                easing.type: Easing.OutCubic
                            }
                            NumberAnimation {
                                target: playIcon
                                property: "scale"
                                to: 1
                                duration: Palette.Theme.motionDefault
                                easing.type: Easing.OutBack
                                easing.overshoot: Palette.Theme.springBouncy
                            }
                        }
                    }

                    MouseArea {
                        id: playMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (root.player && root.player.canTogglePlaying)
                            root.player.togglePlaying()
                    }
                }

                SkipControl {
                    icon: "skip_next"
                    direction: 1
                    enabled: root.hasPlayer && root.player.canGoNext
                    onClicked: root.player.next()
                }

                ToggleControl {
                    // off → all → one
                    icon: supported && root.player.loopState === MprisLoopState.Track ? "repeat_one" : "repeat"
                    supported: root.hasPlayer && root.player.loopSupported
                    on: supported && root.player.loopState !== MprisLoopState.None
                    onClicked: {
                        var l = root.player.loopState;
                        root.player.loopState = l === MprisLoopState.None ? MprisLoopState.Playlist : (l === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None);
                    }
                }
            }
        }
    }

    // Track change: art pops, info slides in.
    ParallelAnimation {
        id: trackChange
        SequentialAnimation {
            NumberAnimation {
                target: art
                property: "scale"
                to: 0.9
                duration: Palette.Theme.effectFast
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: art
                property: "scale"
                to: 1
                duration: Palette.Theme.motionDefault
                easing.type: Easing.OutBack
                easing.overshoot: Palette.Theme.springBouncy
            }
        }
        NumberAnimation {
            target: infoShift
            property: "x"
            from: 14
            to: 0
            duration: Palette.Theme.motionDefault
            easing.type: Easing.OutBack
            easing.overshoot: Palette.Theme.springOvershoot
        }
        NumberAnimation {
            target: info
            property: "opacity"
            from: 0
            to: 1
            duration: Palette.Theme.effectDefault
            easing.type: Easing.OutCubic
        }
    }

    // Previous / next: a tonal circle whose icon nudges the way it skips.
    component SkipControl: Rectangle {
        id: skip

        property string icon: ""
        property int direction: 1
        signal clicked

        implicitWidth: 30
        implicitHeight: 30
        radius: skipMouse.pressed ? Palette.Theme.radiusSmall : width / 2
        color: Qt.alpha(Palette.Theme.textPrimary, 0.08)
        opacity: enabled ? 1 : 0.35
        scale: skipMouse.pressed ? 0.9 : 1

        Behavior on radius {
            SpatialMotion {
                fast: true
            }
        }
        Behavior on scale {
            SpatialMotion {
                fast: true
                bouncy: true
            }
        }

        StateLayer {
            radius: parent.radius
            hovered: skipMouse.containsMouse
            pressed: skipMouse.pressed
        }

        Text {
            id: skipIcon
            anchors.centerIn: parent
            text: skip.icon
            color: Palette.Theme.textPrimary
            font.family: Palette.Theme.fontIcons
            font.pixelSize: Palette.Theme.iconSize

            transform: Translate {
                id: nudge
            }
        }

        SequentialAnimation {
            id: nudgeAnim
            NumberAnimation {
                target: nudge
                property: "x"
                to: 5 * skip.direction
                duration: Palette.Theme.effectFast
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: nudge
                property: "x"
                to: 0
                duration: Palette.Theme.motionDefault
                easing.type: Easing.OutBack
                easing.overshoot: Palette.Theme.springBouncy
            }
        }

        MouseArea {
            id: skipMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: skip.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                nudgeAnim.restart();
                skip.clicked();
            }
        }
    }

    // Shuffle / repeat: quiet when off; when on, a tonal accent background
    // morphs in and the circle squares off a little.
    component ToggleControl: Rectangle {
        id: toggle

        property string icon: ""
        property bool supported: true
        property bool on: false
        signal clicked

        implicitWidth: 28
        implicitHeight: 28
        radius: on ? Palette.Theme.radiusSmall : width / 2
        color: on ? Palette.Theme.accentTonal : "transparent"
        opacity: supported ? 1 : 0.3
        scale: toggleMouse.pressed ? 0.88 : 1

        Behavior on radius {
            SpatialMotion {}
        }
        Behavior on color {
            ColorMotion {}
        }
        Behavior on scale {
            SpatialMotion {
                fast: true
                bouncy: true
            }
        }

        StateLayer {
            radius: parent.radius
            hovered: toggleMouse.containsMouse
            pressed: toggleMouse.pressed
        }

        Text {
            anchors.centerIn: parent
            text: toggle.icon
            color: toggle.on ? Palette.Theme.accent : Palette.Theme.textSecondary
            font.family: Palette.Theme.fontIcons
            font.pixelSize: Palette.Theme.iconSizeSmall

            Behavior on color {
                ColorMotion {}
            }
        }

        MouseArea {
            id: toggleMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: toggle.supported
            cursorShape: Qt.PointingHandCursor
            onClicked: toggle.clicked()
        }
    }
}
