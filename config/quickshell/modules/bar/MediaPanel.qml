import Quickshell
import Quickshell.Services.Mpris
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
        if (visible)
            forceActiveFocus();
    }

    implicitWidth: 480
    implicitHeight: 128

    // ── MPRIS player selection ────────────────────────────────────────────────
    property var player: {
        var list = Mpris.players.values;
        if (list.length === 0)
            return null;
        for (var i = 0; i < list.length; i++) {
            if (list[i].isPlaying)
                return list[i];
        }
        return list[0];
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

    // ── Content ───────────────────────────────────────────────────────────────
    Item {
        id: body
        anchors.fill: parent
        anchors.margins: 16

        SystemClock {
            id: panelClock
            precision: SystemClock.Minutes
        }

        RowLayout {
            anchors.fill: parent
            spacing: 16

            // Album art
            Rectangle {
                implicitWidth: 88
                implicitHeight: 88
                radius: Palette.Theme.radiusSmall
                color: Palette.Theme.surfaceContainerHigh
                clip: true
                Layout.alignment: Qt.AlignVCenter

                Image {
                    id: artImg
                    anchors.fill: parent
                    source: root.player ? root.player.trackArtUrl : ""
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
                    text: "\ue405"
                    font.family: Palette.Theme.fontIcons
                    font.pixelSize: 34
                    color: Palette.Theme.textSecondary
                    opacity: artImg.status === Image.Null || artImg.status === Image.Error ? 1 : 0
                    Behavior on opacity {
                        EffectMotion {}
                    }
                }
            }

            // Track info + controls
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: root.player ? (root.player.trackTitle || "Unknown Title") : "Nothing playing"
                        color: Palette.Theme.textTitle
                        font.family: Palette.Theme.fontMono
                        font.pixelSize: Palette.Theme.fontSizeBody
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    ColumnLayout {
                        spacing: 0
                        Layout.alignment: Qt.AlignTop | Qt.AlignRight
                        Layout.topMargin: 6

                        Text {
                            text: Qt.formatDateTime(panelClock.date, "hh:mm")
                            color: Palette.Theme.textSecondary
                            font.family: Palette.Theme.fontMono
                            font.pixelSize: Palette.Theme.fontSizeTitle
                            font.weight: Font.Bold
                            Layout.alignment: Qt.AlignRight
                        }

                        Text {
                            text: Qt.formatDateTime(panelClock.date, "ddd, MMM d")
                            color: Palette.Theme.textMuted
                            font.family: Palette.Theme.fontMono
                            font.pixelSize: Palette.Theme.fontSizeXs
                            font.weight: Font.DemiBold
                            Layout.alignment: Qt.AlignRight
                        }
                    }
                }

                Text {
                    text: root.player ? (root.player.trackArtist || "") : ""
                    color: Palette.Theme.textSecondary
                    font.family: Palette.Theme.fontMono
                    font.pixelSize: Palette.Theme.fontSizeBody
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.topMargin: -4
                    visible: text !== ""
                }

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 10
                    spacing: 12

                    // Previous
                    Text {
                        id: prevBtn
                        text: "\ue045"
                        color: Palette.Theme.textPrimary
                        font.family: Palette.Theme.fontIcons
                        font.pixelSize: Palette.Theme.iconSizeLarge
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        Layout.preferredWidth: 18
                        Layout.preferredHeight: 18
                        opacity: root.player && root.player.canGoPrevious ? 1.0 : 0.35
                        Layout.alignment: Qt.AlignVCenter
                        Behavior on opacity {
                            EffectMotion {}
                        }
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -8
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (root.player && root.player.canGoPrevious) root.player.previous()
                            onPressed: prevBtn.opacity = 0.6
                            onReleased: prevBtn.opacity = root.player && root.player.canGoPrevious ? 1.0 : 0.35
                        }
                    }

                    // Play / Pause with circular progress
                    Item {
                        implicitWidth: 38
                        implicitHeight: 38
                        Layout.alignment: Qt.AlignVCenter

                        CookieShape {
                            anchors.centerIn: parent
                            width: 26
                            height: 26
                            color: Palette.Theme.textPrimary
                        }

                        Text {
                            id: playPauseBtn
                            anchors.centerIn: parent
                            width: 26
                            height: 26
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            text: root.hasPlayer && root.player.isPlaying ? "\ue034" : "\ue037"
                            color: Palette.Theme.accentText
                            font.family: Palette.Theme.fontIcons
                            font.pixelSize: Palette.Theme.iconSizeLarge
                            Behavior on scale {
                                SpatialMotion {
                                    fast: true
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (root.player && root.player.canTogglePlaying) root.player.togglePlaying()
                            onPressed: playPauseBtn.scale = 0.88
                            onReleased: playPauseBtn.scale = 1.0
                        }
                    }

                    // Next
                    Text {
                        id: nextBtn
                        text: "\ue044"
                        color: Palette.Theme.textPrimary
                        font.family: Palette.Theme.fontIcons
                        font.pixelSize: Palette.Theme.iconSizeLarge
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        Layout.preferredWidth: 18
                        Layout.preferredHeight: 18
                        opacity: root.player && root.player.canGoNext ? 1.0 : 0.35
                        Layout.alignment: Qt.AlignVCenter
                        Behavior on opacity {
                            EffectMotion {}
                        }
                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -8
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (root.player && root.player.canGoNext) root.player.next()
                            onPressed: nextBtn.opacity = 0.6
                            onReleased: nextBtn.opacity = root.player && root.player.canGoNext ? 1.0 : 0.35
                        }
                    }

                    // Seek / progress wave
                    Item {
                        id: waveArea
                        Layout.fillWidth: true
                        implicitHeight: 18
                        Layout.alignment: Qt.AlignVCenter

                        property bool dragging: false
                        property bool hovering: false
                        property real dragProgress: 0
                        readonly property bool canSeek: root.hasPlayer && root.player && root.player.canSeek !== false

                        Canvas {
                            id: wave
                            anchors.centerIn: parent
                            width: parent.width
                            height: 20

                            readonly property real amplitude: 2.0
                            readonly property real wavelength: 15.0
                            property real phase: 0

                            NumberAnimation on phase {
                                from: 0; to: wave.wavelength
                                duration: 1000
                                loops: Animation.Infinite
                                running: root.hasPlayer && root.player && root.player.isPlaying && wave.visible && !waveArea.dragging
                            }

                            property real animProg: waveArea.dragging ? waveArea.dragProgress : root.progress
                            Behavior on animProg {
                                enabled: !waveArea.dragging
                                EffectMotion {
                                    fast: false
                                }
                            }

                            onPhaseChanged: requestPaint()
                            onAnimProgChanged: requestPaint()
                            onWidthChanged: requestPaint()
                            onVisibleChanged: if (visible) requestPaint()

                            Connections {
                                target: waveArea
                                function onDraggingChanged() { wave.requestPaint(); }
                                function onHoveringChanged() { wave.requestPaint(); }
                            }

                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.reset();
                                var w = width, h = height, mid = h / 2;
                                var splitX = w * animProg;
                                ctx.lineCap = "round";
                                ctx.lineJoin = "round";

                                if (splitX > 0) {
                                    ctx.beginPath();
                                    ctx.strokeStyle = Palette.Theme.accent;
                                    ctx.lineWidth = 1.8;
                                    for (var x = 0; x <= splitX; x++) {
                                        var y = mid + Math.sin((x / wavelength + phase / wavelength) * Math.PI * 2) * amplitude;
                                        x === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
                                    }
                                    ctx.stroke();
                                }
                                if (splitX < w) {
                                    ctx.beginPath();
                                    ctx.strokeStyle = Palette.Theme.border;
                                    ctx.lineWidth = 2;
                                    ctx.moveTo(splitX, mid);
                                    ctx.lineTo(w, mid);
                                    ctx.stroke();
                                }

                                var tipHeight = waveArea.dragging ? h * 0.9 : h * 0.7;
                                ctx.beginPath();
                                ctx.strokeStyle = Palette.Theme.accent;
                                ctx.lineWidth = waveArea.dragging ? 2.4 : 2.0;
                                ctx.moveTo(splitX, mid - tipHeight / 2);
                                ctx.lineTo(splitX, mid + tipHeight / 2);
                                ctx.stroke();

                                if (waveArea.hovering || waveArea.dragging) {
                                    ctx.beginPath();
                                    ctx.fillStyle = Palette.Theme.accent;
                                    ctx.globalAlpha = 0.25;
                                    ctx.arc(splitX, mid, waveArea.dragging ? 6 : 5, 0, Math.PI * 2);
                                    ctx.fill();
                                    ctx.globalAlpha = 1.0;
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: waveArea.canSeek
                            cursorShape: waveArea.canSeek ? Qt.PointingHandCursor : Qt.ArrowCursor

                            function updateDragPos(mx) {
                                waveArea.dragProgress = Math.min(1, Math.max(0, mx / width));
                            }
                            function commitSeek(mx) {
                                var frac = Math.min(1, Math.max(0, mx / width));
                                waveArea.dragProgress = frac;
                                if (root.player && root.player.length > 0) {
                                    root.player.position = frac * root.player.length;
                                    root.player.positionChanged();
                                }
                            }

                            onEntered: waveArea.hovering = true
                            onExited: waveArea.hovering = false
                            onPressed: mouse => { waveArea.dragging = true; updateDragPos(mouse.x); }
                            onPositionChanged: mouse => { if (waveArea.dragging) updateDragPos(mouse.x); }
                            onReleased: mouse => { commitSeek(mouse.x); waveArea.dragging = false; }
                        }
                    }
                }
            }
        }
    }
}
