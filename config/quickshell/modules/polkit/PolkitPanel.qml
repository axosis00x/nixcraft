import Quickshell
import Quickshell.Services.Polkit
import QtQuick
import QtQuick.Layouts
import "../../theme" as Palette
import "../../components/material"

// The shell's polkit agent: asks for the password from the top notch
// when an app needs privileges. Only one agent can run per session.
Item {
    id: root

    visible: false
    // Still visible while the close delay runs, but on its way out.
    readonly property bool closing: closeTimer.running
    focus: visible

    property real maxWidth: 4000

    readonly property var flow: agent.flow
    // Waiting on polkit after a submit, until it asks again or finishes.
    property bool busy: false
    // Set when polkit rejects a password, until the next keystroke.
    property bool wrong: false

    implicitWidth: Math.min(maxWidth - 24, 380)
    implicitHeight: content.implicitHeight + 40

    signal aboutToOpen
    signal aboutToClose

    PolkitAgent {
        id: agent
    }

    Connections {
        target: agent
        function onIsActiveChanged() {
            if (agent.isActive)
                root.open();
            else
                root.close();
        }
    }

    Connections {
        target: root.flow
        ignoreUnknownSignals: true
        function onIsResponseRequiredChanged() {
            if (root.flow.isResponseRequired) {
                root.busy = false;
                field.text = "";
                field.forceActiveFocus();
            }
        }
        function onAuthenticationFailed() {
            root.busy = false;
            root.wrong = true;
            field.text = "";
            shake.restart();
        }
    }

    function open() {
        if (visible && !closing)
            return;
        busy = false;
        wrong = false;
        field.text = "";
        closeTimer.stop();
        aboutToOpen();
        visible = true;
        field.forceActiveFocus();
    }

    // Closing while a request is still pending (Esc, Cancel, a click
    // outside) cancels it, so the asking app gets a clean "dismissed".
    function close() {
        if (agent.isActive && flow && !flow.isCompleted)
            flow.cancelAuthenticationRequest();
        if (!visible)
            return;
        if (!closing) {
            aboutToClose();
            closeTimer.start();
        }
    }

    function submit() {
        if (!flow || busy || !flow.isResponseRequired)
            return;
        busy = true;
        wrong = false;
        flow.submit(field.text);
    }

    Timer {
        id: closeTimer
        interval: 180
        onTriggered: {
            root.visible = false;
            field.text = "";
        }
    }

    Keys.onEscapePressed: root.close()

    // A short side-to-side shake when the password is wrong.
    SequentialAnimation {
        id: shake
        loops: 1
        NumberAnimation { target: content; property: "anchors.horizontalCenterOffset"; to: -10; duration: 50; easing.type: Easing.OutCubic }
        NumberAnimation { target: content; property: "anchors.horizontalCenterOffset"; to: 8; duration: 70; easing.type: Easing.InOutCubic }
        NumberAnimation { target: content; property: "anchors.horizontalCenterOffset"; to: -5; duration: 60; easing.type: Easing.InOutCubic }
        NumberAnimation { target: content; property: "anchors.horizontalCenterOffset"; to: 0; duration: 60; easing.type: Easing.OutCubic }
    }

    ColumnLayout {
        id: content
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 20
        width: parent.width - 40
        spacing: 0

        // Header, centred: lock badge, title, the asking app's message.
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 52
            Layout.preferredHeight: 52
            radius: Palette.Theme.radiusSmall
            color: root.wrong ? Qt.alpha(Palette.Theme.errorColor, 0.18) : Palette.Theme.accentTonal

            Behavior on color {
                ColorMotion {}
            }

            Text {
                anchors.centerIn: parent
                text: root.wrong ? "lock_reset" : "shield_lock"
                color: root.wrong ? Palette.Theme.errorColor : Palette.Theme.accent
                font.family: Palette.Theme.fontIcons
                font.weight: Palette.Theme.iconWeight
                font.pixelSize: Palette.Theme.iconSizeLarge + 4
            }
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 14
            horizontalAlignment: Text.AlignHCenter
            text: "Authentication required"
            color: Palette.Theme.textPrimary
            font.family: Palette.Theme.fontSans
            font.pixelSize: Palette.Theme.fontSizeHeadline
            font.weight: Font.DemiBold
        }

        Text {
            Layout.fillWidth: true
            Layout.topMargin: 4
            horizontalAlignment: Text.AlignHCenter
            text: root.flow ? root.flow.message : ""
            color: Palette.Theme.textSecondary
            font.family: Palette.Theme.fontSans
            font.pixelSize: Palette.Theme.fontSizeSmall
            lineHeight: 1.15
            wrapMode: Text.WordWrap
            maximumLineCount: 4
            elide: Text.ElideRight
            visible: text !== ""
        }

        // Who's authenticating. With several admin identities, click the
        // name to switch between them.
        Row {
            id: identityRow

            readonly property var identities: root.flow ? root.flow.identities : []
            readonly property var current: root.flow ? root.flow.selectedIdentity : null
            readonly property bool switchable: identities.length > 1 && !root.busy

            function label(identity) {
                if (!identity)
                    return "";
                return identity.displayName || identity.string || String(identity);
            }

            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 10
            visible: current !== null && current !== undefined
            spacing: 4

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Signing in as"
                color: Palette.Theme.textMuted
                font.family: Palette.Theme.fontSans
                font.pixelSize: Palette.Theme.fontSizeXs
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: identityRow.label(identityRow.current) + (identityRow.switchable ? "  ▾" : "")
                color: identityMouse.containsMouse && identityRow.switchable ? Palette.Theme.accent : Palette.Theme.textPrimary
                font.family: Palette.Theme.fontSans
                font.pixelSize: Palette.Theme.fontSizeXs
                font.weight: Font.DemiBold

                MouseArea {
                    id: identityMouse
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    enabled: identityRow.switchable
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        var list = identityRow.identities;
                        var i = list.indexOf(identityRow.current);
                        root.flow.selectedIdentity = list[(i + 1) % list.length];
                    }
                }
            }
        }

        // The password (or whatever polkit's prompt asks for).
        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 16
            implicitHeight: 38
            radius: Palette.Theme.radiusSmall
            color: Palette.Theme.surfaceContainerHigh
            border.width: field.activeFocus || root.wrong ? 2 : 1
            border.color: root.wrong ? Palette.Theme.errorColor : (field.activeFocus ? Palette.Theme.accent : Palette.Theme.outlineSoft)

            Behavior on border.color {
                ColorMotion {}
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 6
                spacing: 10

                Text {
                    text: "key"
                    color: field.activeFocus ? Palette.Theme.accent : Palette.Theme.textMuted
                    font.family: Palette.Theme.fontIcons
                    font.weight: Palette.Theme.iconWeight
                    font.pixelSize: Palette.Theme.iconSizeSmall

                    Behavior on color {
                        ColorMotion {}
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    TextInput {
                        id: field
                        anchors.fill: parent
                        verticalAlignment: TextInput.AlignVCenter
                        color: Palette.Theme.textPrimary
                        selectionColor: Palette.Theme.accentTonal
                        selectedTextColor: Palette.Theme.textPrimary
                        font.family: Palette.Theme.fontSans
                        font.pixelSize: Palette.Theme.fontSizeBody
                        echoMode: root.flow && root.flow.responseVisible || reveal.on ? TextInput.Normal : TextInput.Password
                        passwordCharacter: "•"
                        enabled: !root.busy
                        clip: true
                        onTextEdited: root.wrong = false
                        Keys.onReturnPressed: root.submit()
                        Keys.onEnterPressed: root.submit()
                        Keys.onEscapePressed: root.close()
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: field.text === ""
                        text: {
                            var prompt = root.flow ? root.flow.inputPrompt.trim() : "";
                            prompt = prompt.replace(/:$/, "");
                            return prompt === "" ? "Password" : prompt;
                        }
                        color: Palette.Theme.textMuted
                        font.family: Palette.Theme.fontSans
                        font.pixelSize: Palette.Theme.fontSizeBody
                    }
                }

                IconButton {
                    id: reveal
                    property bool on: false
                    visible: !(root.flow && root.flow.responseVisible)
                    icon: on ? "visibility_off" : "visibility"
                    implicitWidth: 28
                    implicitHeight: 28
                    stateRadius: Palette.Theme.radiusXs
                    iconSize: Palette.Theme.iconSizeSmall
                    onClicked: {
                        on = !on;
                        field.forceActiveFocus();
                    }
                }
            }
        }

        // polkit's own notes, or ours when the password was wrong.
        Text {
            Layout.fillWidth: true
            Layout.topMargin: 8
            Layout.leftMargin: 4
            readonly property string note: root.flow ? root.flow.supplementaryMessage : ""
            visible: text !== ""
            text: root.wrong ? "Wrong password, try again" : note
            color: root.wrong || (root.flow && root.flow.supplementaryIsError) ? Palette.Theme.errorColor : Palette.Theme.textSecondary
            font.family: Palette.Theme.fontSans
            font.pixelSize: Palette.Theme.fontSizeXs
            wrapMode: Text.WordWrap
        }

        // Two equal buttons: cancel (tonal) and authenticate (filled).
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 12
            spacing: 10

            DialogButton {
                Layout.fillWidth: true
                label: "Cancel"
                onClicked: root.close()
            }

            DialogButton {
                Layout.fillWidth: true
                label: root.busy ? "Checking…" : "Authenticate"
                filled: true
                enabled: !root.busy && field.text !== ""
                onClicked: root.submit()
            }
        }

        // Which polkit action this is, for the curious.
        Text {
            Layout.fillWidth: true
            Layout.topMargin: 12
            horizontalAlignment: Text.AlignHCenter
            text: root.flow ? root.flow.actionId : ""
            color: Palette.Theme.textMuted
            opacity: 0.8
            font.family: Palette.Theme.fontMono
            font.pixelSize: Palette.Theme.fontSizeXs - 1
            elide: Text.ElideMiddle
        }
    }

    // A dialog button: same height and corners as the field above.
    component DialogButton: Rectangle {
        id: button

        property string label: ""
        property bool filled: false
        signal clicked

        implicitHeight: 34
        radius: Palette.Theme.radiusSmall
        color: filled ? Palette.Theme.accent : Palette.Theme.surfaceContainerHigh
        opacity: enabled ? 1 : 0.45
        scale: buttonMouse.pressed ? 0.96 : 1

        Behavior on scale {
            SpatialMotion {
                fast: true
                bouncy: true
            }
        }
        Behavior on opacity {
            EffectMotion {}
        }

        StateLayer {
            radius: button.radius
            tone: button.filled ? Palette.Theme.accentText : Palette.Theme.textPrimary
            hovered: buttonMouse.containsMouse
            pressed: buttonMouse.pressed
        }

        Text {
            anchors.centerIn: parent
            text: button.label
            color: button.filled ? Palette.Theme.accentText : Palette.Theme.textPrimary
            font.family: Palette.Theme.fontSans
            font.pixelSize: Palette.Theme.fontSizeSmall
            font.weight: Font.DemiBold
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: button.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: button.clicked()
        }
    }
}
