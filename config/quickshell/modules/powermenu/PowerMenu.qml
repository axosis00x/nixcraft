import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../theme" as Palette

Item {
    id: root

    anchors.fill: parent
    visible: false
    focus: visible

    property real maxWidth: 4000
    property var launcher: null
    property var controlCenter: null
    property int selectedIndex: 0
    property string confirmAction: ""
    property bool confirmChoiceSelected: false

    implicitWidth: Math.min(maxWidth - 24, confirmAction === "" ? 288 : 220)
    implicitHeight: content.implicitHeight + 16

    signal aboutToOpen
    signal aboutToClose

    readonly property var actions: [
        {
            name: "Lock",
            icon: "\ue897",
            command: ["qs", "ipc", "call", "lockscreen", "lock"]
        },
        {
            name: "Sleep",
            icon: "\ue51c",
            command: ["systemctl", "suspend"]
        },
        {
            name: "Logout",
            icon: "\ue9ba",
            command: ["uwsm", "stop"]
        },
        {
            name: "Reboot",
            icon: "\ue5d5",
            command: ["systemctl", "reboot"],
            dangerous: true
        },
        {
            name: "Shutdown",
            icon: "\ue8ac",
            command: ["systemctl", "poweroff"],
            dangerous: true
        }
    ]

    IpcHandler {
        target: "powermenu"
        function toggle(): void {
            root.togglePowerMenu();
        }
        function open(): void {
            root.openPowerMenu();
        }
        function close(): void {
            root.closePowerMenu();
        }
    }

    function openPowerMenu() {
        if (launcher && launcher.visible && typeof launcher.closeLauncher === "function")
            launcher.closeLauncher(true);
        if (controlCenter && controlCenter.visible && typeof controlCenter.closeControlCenter === "function")
            controlCenter.closeControlCenter(true);
        if (visible)
            return;
        selectedIndex = 0;
        confirmAction = "";
        confirmChoiceSelected = false;
        aboutToOpen();
        visible = true;
        forceActiveFocus();
    }

    function closePowerMenu(immediate) {
        if (!visible)
            return;
        confirmAction = "";
        aboutToClose();
        if (immediate) {
            closeTimer.stop();
            visible = false;
            return;
        }
        closeTimer.restart();
    }

    function togglePowerMenu() {
        if (visible)
            closePowerMenu();
        else
            openPowerMenu();
    }

    function choose(index) {
        var action = actions[index];
        if (action.dangerous) {
            confirmAction = action.name;
            // Enter must not perform a destructive action by default.
            confirmChoiceSelected = false;
            return;
        }
        run(action);
    }

    function run(action) {
        closePowerMenu(true);
        actionProcess.exec(action.command);
    }

    function confirm() {
        for (var i = 0; i < actions.length; i++) {
            if (actions[i].name === confirmAction) {
                run(actions[i]);
                return;
            }
        }
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            event.accepted = true;
            if (confirmAction !== "")
                confirmAction = "";
            else
                closePowerMenu();
        } else if (confirmAction !== "" && (event.key === Qt.Key_Left || event.key === Qt.Key_Right)) {
            event.accepted = true;
            confirmChoiceSelected = !confirmChoiceSelected;
        } else if (confirmAction !== "" && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
            event.accepted = true;
            if (confirmChoiceSelected)
                confirm();
            else
                confirmAction = "";
        } else if (confirmAction === "" && event.key === Qt.Key_Left) {
            event.accepted = true;
            selectedIndex = (selectedIndex + actions.length - 1) % actions.length;
        } else if (confirmAction === "" && event.key === Qt.Key_Right) {
            event.accepted = true;
            selectedIndex = (selectedIndex + 1) % actions.length;
        } else if (confirmAction === "" && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)) {
            event.accepted = true;
            choose(selectedIndex);
        }
    }

    Process {
        id: actionProcess
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 8
        spacing: 6

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 8
            visible: confirmAction === ""

            Repeater {
                model: root.actions

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    Layout.minimumWidth: 48
                    Layout.preferredWidth: 48
                    Layout.maximumWidth: 48
                    implicitHeight: 48
                    radius: 14
                    scale: actionMouse.pressed ? 0.90 : (actionMouse.containsMouse ? 1.08 : 1.0)
                    Behavior on scale {
                        NumberAnimation {
                            duration: 150
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.6
                        }
                    }

                    color: {
                        if (index === root.selectedIndex)
                            return modelData.dangerous ? "#ff5252" : Palette.Theme.accent;
                        return modelData.dangerous ? (actionMouse.containsMouse ? "#4d1a1a" : "#3d1515") : (actionMouse.containsMouse ? Palette.Theme.surfaceContainerHighest : Palette.Theme.surfaceContainerLow);
                    }
                    border.width: 0

                    Behavior on color { ColorAnimation { duration: 120 } }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: index === root.selectedIndex ? "#ffffff" : Palette.Theme.accent
                        opacity: actionMouse.pressed ? 0.18 : (actionMouse.containsMouse ? 0.08 : 0)
                        Behavior on opacity { NumberAnimation { duration: 120 } }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.icon
                        color: index === root.selectedIndex
                            ? (modelData.dangerous ? "#ffffff" : Palette.Theme.accentText)
                            : (modelData.dangerous ? "#ff8a80" : Palette.Theme.textPrimary)
                        font.family: Palette.Theme.fontIcons
                        font.pixelSize: 20
                    }

                    MouseArea {
                        id: actionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.selectedIndex = index
                        onClicked: root.choose(index)
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: confirmAction !== ""
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 46
                    radius: 12
                    color: root.confirmChoiceSelected ? Palette.Theme.accent : Palette.Theme.surfaceContainerLow
                    scale: confirmMouse.pressed ? 0.94 : (confirmMouse.containsMouse ? 1.03 : 1.0)
                    Behavior on scale {
                        NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 1.5 }
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "\ue5ca"
                            color: root.confirmChoiceSelected ? Palette.Theme.accentText : Palette.Theme.textPrimary
                            font.family: Palette.Theme.fontIcons
                            font.pixelSize: 16
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: confirmAction
                            color: root.confirmChoiceSelected ? Palette.Theme.accentText : Palette.Theme.textPrimary
                            font.family: Palette.Theme.fontSans
                            font.pixelSize: 11
                            font.weight: Font.Medium
                        }
                    }

                    MouseArea {
                        id: confirmMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.confirmChoiceSelected = true
                        onClicked: root.confirm()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 46
                    radius: 12
                    // The primary background follows keyboard/mouse focus,
                    // including the X/Cancel choice.
                    color: !root.confirmChoiceSelected ? Palette.Theme.accent : Palette.Theme.surfaceContainerLow
                    scale: cancelMouse.pressed ? 0.94 : (cancelMouse.containsMouse ? 1.03 : 1.0)
                    Behavior on scale {
                        NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 1.5 }
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "\ue5cd"
                            color: !root.confirmChoiceSelected ? Palette.Theme.accentText : Palette.Theme.textPrimary
                            font.family: Palette.Theme.fontIcons
                            font.pixelSize: 16
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Cancel"
                            color: !root.confirmChoiceSelected ? Palette.Theme.accentText : Palette.Theme.textPrimary
                            font.family: Palette.Theme.fontSans
                            font.pixelSize: 11
                            font.weight: Font.Medium
                        }
                    }

                    MouseArea {
                        id: cancelMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.confirmChoiceSelected = false
                        onClicked: root.confirmAction = ""
                    }
                }
            }
        }
    }

    Timer {
        id: closeTimer
        interval: 180
        onTriggered: root.visible = false
    }
}