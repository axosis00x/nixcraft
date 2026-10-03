import Quickshell
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../theme" as Palette
import "../../components/material"
import QtQuick.Controls

PopupWindow {
    id: popup

    required property var bar

    anchor.window: bar
    anchor.rect.x: bar.width / 2 - width / 2
    anchor.rect.y: 4

    color: "transparent"
    visible: false
    grabFocus: true

    implicitWidth: 480
    implicitHeight: 134

    property bool isOpen: false

    function open() {
        visible = true;
        isOpen = true;
        openAnim.restart();
    }

    function forceClose() {
        isOpen = false;
        closeAnim.restart();
    }

    onVisibleChanged: if (!visible) {
        isOpen = false;
        closeAnim.stop();
        shell.height = 30;
        shell.opacity = 0;
        body.opacity = 0;
    }

    Timer {
        id: hideTimer
        interval: 340
        onTriggered: if (!popup.isOpen)
            popup.visible = false
    }

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

    Timer {
        interval: 500
        running: popup.visible && popup.hasPlayer && popup.player.isPlaying
        repeat: true
        onTriggered: if (popup.player)
            popup.player.positionChanged()
    }

    SequentialAnimation {
        id: openAnim
        PropertyAction {
            target: shell
            property: "height"
            value: 30
        }
        PropertyAction {
            target: shell
            property: "opacity"
            value: 0
        }
        ParallelAnimation {
            NumberAnimation {
                target: shell
                property: "opacity"
                to: 1
                duration: 130
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: shell
                property: "height"
                to: 120
                duration: 270
                easing.type: Easing.OutCubic
            }
        }
        NumberAnimation {
            target: body
            property: "opacity"
            to: 1
            duration: 170
            easing.type: Easing.OutCubic
        }
    }

    SequentialAnimation {
        id: closeAnim
        NumberAnimation {
            target: body
            property: "opacity"
            to: 0
            duration: 110
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: shell
            property: "height"
            to: 30
            duration: 230
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: shell
            property: "opacity"
            to: 0
            duration: 100
            easing.type: Easing.InCubic
        }
        ScriptAction {
            script: hideTimer.restart()
        }
    }

    Surface {
        id: shell
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        height: 30
        radius: Palette.Theme.radiusMedium
        clip: true
        opacity: 0

        Rectangle {
            id: cornerMask
            anchors.fill: parent
            radius: shell.radius
            visible: false
            layer.enabled: true
        }

        Item {
            id: roundedContent
            anchors.fill: parent
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: cornerMask
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1.0
            }

            Image {
                id: bgArt
                anchors.fill: parent
                source: popup.player ? popup.player.trackArtUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                opacity: status === Image.Ready ? 0.5 : 0
                visible: false

                Behavior on opacity {
                    EffectMotion {
                        fast: false
                    }
                }
            }

            MultiEffect {
                anchors.fill: bgArt
                source: bgArt
                blurEnabled: true
                blur: 0.4
                blurMax: 64
                opacity: bgArt.opacity

                Rectangle {
                    anchors.fill: parent
                    color: "black"
                    opacity: 0.3
                }
            }

            Item {
                id: body
                anchors.fill: parent
                anchors.margins: 16
                opacity: 0

                SystemClock {
                    id: mediaClock
                    precision: SystemClock.Minutes
                }

                RowLayout {
                    anchors.fill: parent
                    spacing: 16

                    Rectangle {
                        implicitWidth: 88
                        implicitHeight: 88
                        radius: Palette.Theme.radiusMedium
                        color: Palette.Theme.surfaceContainerHigh
                        clip: true
                        Layout.alignment: Qt.AlignVCenter

                        Image {
                            id: artImg
                            anchors.fill: parent
                            source: popup.player ? popup.player.trackArtUrl : ""
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

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 0

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: popup.player ? (popup.player.trackTitle || "Unknown Title") : "Nothing playing"
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
                                    text: Qt.formatDateTime(mediaClock.date, "hh:mm")
                                    color: Palette.Theme.textSecondary
                                    font.family: Palette.Theme.fontMono
                                    font.pixelSize: Palette.Theme.fontSizeTitle
                                    font.weight: Font.Bold
                                    Layout.alignment: Qt.AlignRight
                                }

                                Text {
                                    text: Qt.formatDateTime(mediaClock.date, "ddd, MMM d")
                                    color: Palette.Theme.textMuted
                                    font.family: Palette.Theme.fontMono
                                    font.pixelSize: Palette.Theme.fontSizeXs
                                    font.weight: Font.DemiBold
                                    Layout.alignment: Qt.AlignRight
                                }
                            }
                        }

                        Text {
                            text: popup.player ? (popup.player.trackArtist || "") : ""
                            color: Palette.Theme.textSecondary
                            font.family: Palette.Theme.fontMono
                            font.pixelSize: Palette.Theme.fontSizeBody
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                            Layout.topMargin: -4
                            visible: text !== ""
                        }

                        Item {
                            Layout.fillHeight: true
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 10
                            spacing: 12

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
                                opacity: popup.player && popup.player.canGoPrevious ? 1.0 : 0.35
                                Layout.alignment: Qt.AlignVCenter

                                Behavior on opacity {
                                    EffectMotion {}
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -8
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (popup.player && popup.player.canGoPrevious)
                                        popup.player.previous()
                                    onPressed: prevBtn.opacity = 0.6
                                    onReleased: prevBtn.opacity = popup.player && popup.player.canGoPrevious ? 1.0 : 0.35
                                }
                            }

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
                                    text: popup.hasPlayer && popup.player.isPlaying ? "\ue034" : "\ue037"
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
                                    onClicked: if (popup.player && popup.player.canTogglePlaying)
                                        popup.player.togglePlaying()
                                    onPressed: playPauseBtn.scale = 0.88
                                    onReleased: playPauseBtn.scale = 1.0
                                }
                            }

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
                                opacity: popup.player && popup.player.canGoNext ? 1.0 : 0.35
                                Layout.alignment: Qt.AlignVCenter

                                Behavior on opacity {
                                    EffectMotion {}
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -8
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (popup.player && popup.player.canGoNext)
                                        popup.player.next()
                                    onPressed: nextBtn.opacity = 0.6
                                    onReleased: nextBtn.opacity = popup.player && popup.player.canGoNext ? 1.0 : 0.35
                                }
                            }

                            Item {
                                id: waveArea
                                Layout.fillWidth: true
                                implicitHeight: 18
                                Layout.alignment: Qt.AlignVCenter

                                property bool dragging: false
                                property bool hovering: false
                                property real dragProgress: 0
                                readonly property bool canSeek: popup.hasPlayer && popup.player.canSeek !== false

                                Canvas {
                                    id: wave
                                    anchors.centerIn: parent
                                    width: parent.width
                                    height: 20

                                    readonly property real amplitude: 2.0
                                    readonly property real wavelength: 15.0
                                    property real phase: 0

                                    NumberAnimation on phase {
                                        from: 0
                                        to: wave.wavelength
                                        duration: 1000
                                        loops: Animation.Infinite
                                        running: popup.hasPlayer && popup.player.isPlaying && wave.visible && !waveArea.dragging
                                    }

                                    property real animProg: waveArea.dragging ? waveArea.dragProgress : popup.progress
                                    Behavior on animProg {
                                        enabled: !waveArea.dragging
                                        EffectMotion {
                                            fast: false
                                        }
                                    }

                                    onPhaseChanged: requestPaint()
                                    onAnimProgChanged: requestPaint()
                                    onWidthChanged: requestPaint()
                                    onVisibleChanged: if (visible)
                                        requestPaint()

                                    Connections {
                                        target: waveArea
                                        function onDraggingChanged() {
                                            wave.requestPaint();
                                        }
                                        function onHoveringChanged() {
                                            wave.requestPaint();
                                        }
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
                                        var frac = Math.min(1, Math.max(0, mx / width));
                                        waveArea.dragProgress = frac;
                                    }

                                    function commitSeek(mx) {
                                        var frac = Math.min(1, Math.max(0, mx / width));
                                        waveArea.dragProgress = frac;
                                        if (popup.player && popup.player.length > 0) {
                                            popup.player.position = frac * popup.player.length;
                                            popup.player.positionChanged();
                                        }
                                    }

                                    onEntered: waveArea.hovering = true
                                    onExited: waveArea.hovering = false

                                    onPressed: mouse => {
                                        waveArea.dragging = true;
                                        updateDragPos(mouse.x);
                                    }
                                    onPositionChanged: mouse => {
                                        if (waveArea.dragging)
                                            updateDragPos(mouse.x);
                                    }
                                    onReleased: mouse => {
                                        commitSeek(mouse.x);
                                        waveArea.dragging = false;
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
