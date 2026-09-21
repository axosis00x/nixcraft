import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../theme" as Palette
import "../../components/material"

WlSessionLockSurface {
    id: root

    required property var lockScreen

    // Opaque fallback so nothing behind the compositor's lock surface can
    // ever show through before the wallpaper image finishes loading.
    color: "#000000"

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Image {
        id: bg
        anchors.fill: parent
        source: root.lockScreen.wallpaperPath ? "file://" + root.lockScreen.wallpaperPath : ""
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
        blur: 0.5
        blurMax: 48
        brightness: -0.15
        saturation: -0.15
    }

    Rectangle {
        anchors.fill: parent
        color: Palette.Theme.bg
        opacity: 0.32
    }

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
        fadeIn.start();
    }

    ColumnLayout {
        id: content
        anchors.centerIn: parent
        spacing: 16
        width: 340
        opacity: 0

        NumberAnimation {
            id: fadeIn
            target: content
            property: "opacity"
            to: 1
            duration: 320
            easing.type: Easing.OutCubic
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: 96
            height: 96
            radius: 48
            color: Palette.Theme.surfaceContainer
            border.width: 2
            border.color: Palette.Theme.border
            clip: true

            Image {
                anchors.fill: parent
                source: "file://" + Quickshell.env("HOME") + "/Pictures/misc/pfp.png"
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "hi, " + Quickshell.env("USER")
            color: Palette.Theme.textPrimary
            font.family: Palette.Theme.fontMono
            font.pixelSize: 14
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDateTime(clock.date, "hh:mm")
            color: Palette.Theme.textPrimary
            font.family: Palette.Theme.fontMono
            font.pixelSize: 64
            font.weight: Font.Bold
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDateTime(clock.date, "ddd, MMM d")
            color: Palette.Theme.textSecondary
            font.family: Palette.Theme.fontMono
            font.pixelSize: 13
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 10
            spacing: 10

            Item {
                id: pwFieldWrapper
                Layout.preferredWidth: 288
                Layout.preferredHeight: 50
                Layout.alignment: Qt.AlignHCenter

                readonly property bool hasText: root.lockScreen.typed.length > 0
                readonly property color stateColor: root.lockScreen.authFailed ? Palette.Theme.errorColor : Palette.Theme.accent
                readonly property bool canSubmit: hasText && !root.lockScreen.authBusy

                transform: Translate {
                    id: shakeTranslate
                }

                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: Qt.alpha(Palette.Theme.surfaceContainer, 0.72)
                    border.width: 1.5
                    border.color: root.lockScreen.authFailed ? Palette.Theme.errorColor : (pwFieldWrapper.hasText ? Palette.Theme.accent : Qt.alpha(Palette.Theme.border, 0.8))

                    Behavior on border.color {
                        ColorAnimation {
                            duration: 180
                        }
                    }
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 18
                    anchors.verticalCenter: parent.verticalCenter
                    text: ""
                    color: pwFieldWrapper.hasText ? pwFieldWrapper.stateColor : Palette.Theme.textMuted
                    font.family: Palette.Theme.fontIcons
                    font.pixelSize: 18

                    Behavior on color {
                        ColorAnimation {
                            duration: 180
                        }
                    }
                }

                Text {
                    id: placeholder
                    anchors.centerIn: parent
                    text: root.lockScreen.authBusy ? "Verifying…" : "Password"
                    color: Palette.Theme.textMuted
                    font.family: Palette.Theme.fontMono
                    font.pixelSize: 13
                    opacity: pwFieldWrapper.hasText ? 0 : 1

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 140
                        }
                    }

                    SequentialAnimation on opacity {
                        running: root.lockScreen.authBusy
                        loops: Animation.Infinite
                        NumberAnimation {
                            to: 0.45
                            duration: 550
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            to: 1
                            duration: 550
                            easing.type: Easing.InOutSine
                        }
                    }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    opacity: pwFieldWrapper.hasText ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: 140
                        }
                    }

                    Repeater {
                        model: Math.min(root.lockScreen.typed.length, 12)
                        delegate: Rectangle {
                            id: dot
                            width: 8
                            height: 8
                            radius: 4
                            color: pwFieldWrapper.stateColor
                            scale: 0

                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                }
                            }
                            Behavior on scale {
                                NumberAnimation {
                                    duration: 200
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 2
                                }
                            }

                            Component.onCompleted: scale = 1
                        }
                    }
                }

                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 7
                    anchors.verticalCenter: parent.verticalCenter
                    width: 36
                    height: 36
                    radius: 18
                    color: pwFieldWrapper.canSubmit ? pwFieldWrapper.stateColor : Palette.Theme.surfaceContainerHigh
                    scale: submitMouse.pressed && pwFieldWrapper.canSubmit ? 0.92 : 1

                    Behavior on color {
                        ColorAnimation {
                            duration: 180
                        }
                    }
                    Behavior on scale {
                        NumberAnimation {
                            duration: 120
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: ""
                        color: pwFieldWrapper.canSubmit ? Palette.Theme.accentText : Palette.Theme.textMuted
                        font.family: Palette.Theme.fontIcons
                        font.pixelSize: 20

                        Behavior on color {
                            ColorAnimation {
                                duration: 180
                            }
                        }
                    }

                    MouseArea {
                        id: submitMouse
                        anchors.fill: parent
                        enabled: pwFieldWrapper.canSubmit
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.lockScreen.submitTyped()
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                visible: root.lockScreen.failedAttempts > 0
                text: root.lockScreen.failedAttempts + (root.lockScreen.failedAttempts === 1 ? " attempt failed" : " attempts failed")
                color: Palette.Theme.errorColor
                font.family: Palette.Theme.fontMono
                font.pixelSize: 11
            }
        }
    }

    Connections {
        target: root.lockScreen
        function onAuthFailedChanged() {
            if (root.lockScreen.authFailed)
                shakeAnim.restart();
        }
        function onAuthBusyChanged() {
            if (!root.lockScreen.authBusy)
                keyCatcher.forceActiveFocus();
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
            to: -6
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
