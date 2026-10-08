import Quickshell
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../theme" as Palette
import "../../components/material"

// Everything drawn on the lock screen. Kept separate from the session-lock
// surface (LockSurface.qml) so it can also be previewed in a plain window.
//
// Deliberately minimal: the blurred wallpaper, a clock with the date, and a
// slim password pill. Enter unlocks; Escape clears.
Item {
    id: root

    required property var lockScreen

    // Drives the entrance: everything eases into place once shown.
    property bool shown: false

    readonly property bool hasText: lockScreen.typed.length > 0
    readonly property color stateColor: lockScreen.authFailed ? Palette.Theme.errorColor : Palette.Theme.accent

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // ── wallpaper ───────────────────────────────────────────────────
    Image {
        id: bg
        anchors.fill: parent
        source: root.lockScreen.wallpaperPath ? "file://" + root.lockScreen.wallpaperPath : ""
        sourceSize: Qt.size(root.width, root.height)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        cache: false
        visible: false
    }

    MultiEffect {
        anchors.fill: bg
        source: bg
        blurEnabled: true
        blur: 0.75
        blurMax: 48
        brightness: -0.22
        scale: root.shown ? 1 : 1.05

        Behavior on scale {
            NumberAnimation {
                duration: 1200
                easing.type: Easing.OutCubic
            }
        }
    }

    // ── keyboard ────────────────────────────────────────────────────
    // Invisible: exists only to hold keyboard focus (and handle compose /
    // dead keys) so typing works immediately without clicking anything. Its
    // text is mirrored into the shared buffer the visible field renders.
    TextInput {
        id: keyCatcher
        width: 1
        height: 1
        opacity: 0
        echoMode: TextInput.NoEcho
        focus: true
        selectByMouse: false
        // Stays enabled while PAM verifies so focus is never dropped.
        readOnly: root.lockScreen.authBusy

        Keys.onEscapePressed: root.lockScreen.typed = ""

        onTextChanged: {
            if (root.lockScreen.typed !== text)
                root.lockScreen.typed = text;
        }
        onAccepted: root.lockScreen.submitTyped()
    }

    Connections {
        target: root.lockScreen
        function onTypedChanged() {
            if (keyCatcher.text !== root.lockScreen.typed)
                keyCatcher.text = root.lockScreen.typed;
        }
        function onAuthFailedChanged() {
            if (root.lockScreen.authFailed)
                shakeAnim.restart();
        }
        function onAuthBusyChanged() {
            if (!root.lockScreen.authBusy)
                keyCatcher.forceActiveFocus();
        }
    }

    // Re-grab focus whenever the compositor hands this surface the keyboard,
    // or the pointer wanders over it.
    Item {
        Window.onActiveChanged: {
            if (Window.active)
                keyCatcher.forceActiveFocus();
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: keyCatcher.forceActiveFocus()
        onClicked: keyCatcher.forceActiveFocus()
    }

    Component.onCompleted: {
        keyCatcher.forceActiveFocus();
        shown = true;
    }

    // ── clock ───────────────────────────────────────────────────────
    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -parent.height * 0.1 + (root.shown ? 0 : 24)
        spacing: 2
        opacity: root.shown ? 1 : 0

        // Soft shadow keeps the text legible over bright wallpapers.
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.5)
            shadowBlur: 0.8
            shadowVerticalOffset: 2
        }

        Behavior on anchors.verticalCenterOffset {
            SpatialMotion {}
        }
        Behavior on opacity {
            EffectMotion {
                fast: false
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDateTime(clock.date, "hh:mm")
            color: Palette.Theme.textPrimary
            font.family: "SF Pro Display"
            font.pixelSize: 104
            font.weight: Font.Medium
            font.letterSpacing: -2
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDateTime(clock.date, "dddd, MMMM d")
            color: Palette.Theme.textPrimary
            opacity: 0.85
            font.family: Palette.Theme.fontSans
            font.pixelSize: Palette.Theme.fontSizeTitle
            font.weight: Font.DemiBold
        }
    }

    // ── who ─────────────────────────────────────────────────────────
    // Profile picture with the username, sitting just above the password.
    Column {
        anchors.horizontalCenter: field.horizontalCenter
        anchors.bottom: field.top
        anchors.bottomMargin: 20
        spacing: 10
        opacity: field.opacity

        ClippingRectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 72
            height: 72
            radius: width / 2
            color: Qt.rgba(1, 1, 1, 0.12)

            // Initial if the picture is missing.
            Text {
                anchors.centerIn: parent
                visible: avatar.status !== Image.Ready
                text: (Quickshell.env("USER") || "?").charAt(0).toUpperCase()
                color: Palette.Theme.textPrimary
                font.family: Palette.Theme.fontSans
                font.pixelSize: 28
                font.weight: Font.DemiBold
            }

            Image {
                id: avatar
                anchors.fill: parent
                source: "file://" + Quickshell.env("HOME") + "/Pictures/misc/pfp.png"
                sourceSize: Qt.size(144, 144)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Quickshell.env("USER")
            color: Palette.Theme.textPrimary
            font.family: Palette.Theme.fontSans
            font.pixelSize: Palette.Theme.fontSizeTitle
            font.weight: Font.DemiBold
        }
    }

    // ── password ────────────────────────────────────────────────────
    Item {
        id: field
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.shown ? parent.height * 0.14 : parent.height * 0.14 - 24
        width: 260
        height: 44
        opacity: root.shown ? 1 : 0

        Behavior on anchors.bottomMargin {
            SpatialMotion {}
        }
        Behavior on opacity {
            EffectMotion {
                fast: false
            }
        }

        transform: Translate {
            id: shakeTranslate
        }

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Qt.rgba(0, 0, 0, 0.3)
            border.width: 1
            border.color: root.lockScreen.authFailed ? Palette.Theme.errorColor : (root.hasText ? Qt.alpha(Palette.Theme.accent, 0.7) : Qt.rgba(1, 1, 1, 0.12))

            Behavior on border.color {
                ColorMotion {}
            }
        }

        Text {
            anchors.centerIn: parent
            text: root.lockScreen.authBusy ? "Verifying…" : (root.lockScreen.authFailed ? "Wrong password" : "Password")
            color: root.lockScreen.authFailed ? Palette.Theme.errorColor : Qt.rgba(1, 1, 1, 0.5)
            font.family: Palette.Theme.fontSans
            font.pixelSize: Palette.Theme.fontSizeBody
            font.weight: Font.Medium
            opacity: root.hasText ? 0 : 1

            Behavior on opacity {
                EffectMotion {}
            }
        }

        // Typed-character dots. The row glides to stay centred as dots are
        // added or removed (rather than jumping by half a dot), and each new
        // dot eases in from small and transparent — smooth, no bounce.
        Row {
            id: dots
            anchors.verticalCenter: parent.verticalCenter
            x: (parent.width - implicitWidth) / 2
            spacing: 8
            opacity: root.hasText ? 1 : 0

            Behavior on x {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on opacity {
                EffectMotion {}
            }

            Repeater {
                model: Math.min(root.lockScreen.typed.length, 16)
                delegate: Rectangle {
                    id: dot
                    width: 7
                    height: 7
                    radius: 3.5
                    color: root.stateColor
                    scale: 0.3
                    opacity: 0

                    Behavior on color {
                        ColorMotion {}
                    }

                    Component.onCompleted: appear.start()

                    ParallelAnimation {
                        id: appear
                        NumberAnimation {
                            target: dot
                            property: "scale"
                            to: 1
                            duration: 220
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            target: dot
                            property: "opacity"
                            to: 1
                            duration: 160
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }
    }

    SequentialAnimation {
        id: shakeAnim
        NumberAnimation {
            target: shakeTranslate
            property: "x"
            to: -10
            duration: 45
        }
        NumberAnimation {
            target: shakeTranslate
            property: "x"
            to: 8
            duration: 90
        }
        NumberAnimation {
            target: shakeTranslate
            property: "x"
            to: -5
            duration: 90
        }
        NumberAnimation {
            target: shakeTranslate
            property: "x"
            to: 0
            duration: 70
        }
    }
}
