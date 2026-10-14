import Quickshell
import Quickshell.Services.Polkit
import QtQuick
import QtQuick.Layouts
import "../../theme" as Palette
import "../../components/material"

// The shell's polkit authentication agent. Quickshell registers it with
// polkitd; when an app asks for privileges (pkexec, systemctl, a settings
// panel...) this opens from the top notch like the other central panels,
// asks for the password, and closes once polkit is satisfied or the
// request is cancelled. Only one agent can be registered per session, so
// no other polkit agent should be running alongside it.
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

    implicitWidth: Math.min(maxWidth - 24, 400)
    implicitHeight: content.implicitHeight + 32

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
        anchors.topMargin: 16
        width: parent.width - 32
        spacing: 12

        // Lock badge, title and the asking app's message.
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                radius: width / 2
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
                    font.pixelSize: Palette.Theme.iconSizeLarge
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    text: "Authentication required"
                    color: Palette.Theme.textPrimary
                    font.family: Palette.Theme.fontSans
                    font.pixelSize: Palette.Theme.fontSizeTitle
                    font.weight: Font.DemiBold
                }

                Text {
                    Layout.fillWidth: true
                    text: root.flow ? root.flow.message : ""
                    color: Palette.Theme.textSecondary
                    font.family: Palette.Theme.fontSans
                    font.pixelSize: Palette.Theme.fontSizeSmall
                    wrapMode: Text.WordWrap
                    maximumLineCount: 4
                    elide: Text.ElideRight
                    visible: text !== ""
                }
            }
        }

        // Who's authenticating. With several admin identities, click to
        // switch between them.
        Rectangle {
            id: identityChip

            readonly property var identities: root.flow ? root.flow.identities : []
            readonly property var current: root.flow ? root.flow.selectedIdentity : null

            function label(identity) {
                if (!identity)
                    return "";
                return identity.displayName || identity.string || String(identity);
            }

            Layout.alignment: Qt.AlignLeft
            Layout.leftMargin: 56
            visible: current !== null && current !== undefined
            implicitWidth: chipRow.implicitWidth + 20
            implicitHeight: 28
            radius: height / 2
            color: Palette.Theme.surfaceContainerHigh

            StateLayer {
                radius: parent.radius
                hovered: chipMouse.containsMouse && identityChip.identities.length > 1
                pressed: chipMouse.pressed && identityChip.identities.length > 1
            }

            Row {
                id: chipRow
                anchors.centerIn: parent
                spacing: 6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "person"
                    color: Palette.Theme.accent
                    font.family: Palette.Theme.fontIcons
                    font.weight: Palette.Theme.iconWeight
                    font.pixelSize: Palette.Theme.iconSizeSmall
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: identityChip.label(identityChip.current)
                    color: Palette.Theme.textPrimary
                    font.family: Palette.Theme.fontSans
                    font.pixelSize: Palette.Theme.fontSizeSmall
                    font.weight: Font.Medium
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: identityChip.identities.length > 1
                    text: "unfold_more"
                    color: Palette.Theme.textMuted
                    font.family: Palette.Theme.fontIcons
                    font.weight: Palette.Theme.iconWeight
                    font.pixelSize: Palette.Theme.iconSizeSmall
                }
            }

            MouseArea {
                id: chipMouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: identityChip.identities.length > 1 && !root.busy
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    var list = identityChip.identities;
                    var i = list.indexOf(identityChip.current);
                    root.flow.selectedIdentity = list[(i + 1) % list.length];
                }
            }
        }

        // The password (or whatever polkit's prompt asks for).
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 46
            radius: height / 2
            color: Palette.Theme.surfaceContainerHigh
            border.width: field.activeFocus || root.wrong ? 2 : 0
            border.color: root.wrong ? Palette.Theme.errorColor : Palette.Theme.accent

            Behavior on border.color {
                ColorMotion {}
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 18
                anchors.rightMargin: 6
                spacing: 6

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
                    implicitWidth: 34
                    implicitHeight: 34
                    iconSize: Palette.Theme.iconSizeSmall
                    onClicked: {
                        on = !on;
                        field.forceActiveFocus();
                    }
                }
            }
        }

        // polkit's own notes ("Authentication failure" and the like), or
        // ours when the password was wrong.
        Text {
            Layout.fillWidth: true
            Layout.leftMargin: 18
            readonly property string note: root.flow ? root.flow.supplementaryMessage : ""
            visible: text !== ""
            text: root.wrong ? "Wrong password, try again" : note
            color: root.wrong || (root.flow && root.flow.supplementaryIsError) ? Palette.Theme.errorColor : Palette.Theme.textSecondary
            font.family: Palette.Theme.fontSans
            font.pixelSize: Palette.Theme.fontSizeXs
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 2
            spacing: 8

            Text {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                text: root.flow ? root.flow.actionId : ""
                color: Palette.Theme.textMuted
                font.family: Palette.Theme.fontMono
                font.pixelSize: Palette.Theme.fontSizeXs
                elide: Text.ElideMiddle
            }

            ActionChip {
                label: "Cancel"
                onClicked: root.close()
            }

            ActionChip {
                label: root.busy ? "Checking…" : "Authenticate"
                active: true
                enabled: !root.busy && field.text !== ""
                opacity: enabled ? 1 : 0.5
                onClicked: root.submit()
            }
        }
    }
}
