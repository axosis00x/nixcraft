import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../theme" as Palette
import "../../components/material"

Item {
    id: root

    visible: false
    // Still visible while the close delay runs, but on its way out.
    readonly property bool closing: closeTimer.running
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
            launcher.closeLauncher();
        if (controlCenter && controlCenter.visible && typeof controlCenter.closeControlCenter === "function")
            controlCenter.closeControlCenter();
        if (visible && !closing)
            return;
        selectedIndex = 0;
        confirmAction = "";
        confirmChoiceSelected = false;
        closeTimer.stop();
        aboutToOpen();
        visible = true;
        forceActiveFocus();
    }

    function closePowerMenu(immediate) {
        if (!visible)
            return;
        confirmAction = "";
        if (!closing)
            aboutToClose();
        if (immediate) {
            closeTimer.stop();
            visible = false;
            return;
        }
        if (!closing)
            closeTimer.start();
    }

    function togglePowerMenu() {
        if (visible && !closing)
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
                    radius: Palette.Theme.radiusMedium
                    scale: actionMouse.pressed ? 0.92 : 1
                    Behavior on scale {
                        SpatialMotion {
                            fast: true
                        }
                    }

                    color: {
                        if (modelData.dangerous)
                            return Qt.alpha(Palette.Theme.errorColor, index === root.selectedIndex ? 0.22 : 0.09);
                        return index === root.selectedIndex ? Palette.Theme.accent : Palette.Theme.surfaceContainerHigh;
                    }
                    border.width: modelData.dangerous ? 1 : 0
                    border.color: Qt.alpha(Palette.Theme.errorColor, index === root.selectedIndex ? 0.55 : 0.25)

                    Behavior on color {
                        ColorMotion {}
                    }

                    StateLayer {
                        radius: parent.radius
                        tone: modelData.dangerous ? Palette.Theme.errorColor : (index === root.selectedIndex ? Palette.Theme.accentText : Palette.Theme.textPrimary)
                        hovered: actionMouse.containsMouse
                        pressed: actionMouse.pressed
                    }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.icon
                        color: modelData.dangerous ? Palette.Theme.errorColor : (index === root.selectedIndex ? Palette.Theme.accentText : Palette.Theme.textPrimary)
                        font.family: Palette.Theme.fontIcons
                        font.weight: Palette.Theme.iconWeight
                        font.pixelSize: Palette.Theme.iconSize
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
                    radius: Palette.Theme.radiusSmall
                    color: root.confirmChoiceSelected ? Qt.alpha(Palette.Theme.errorColor, 0.20) : Palette.Theme.surfaceContainerLow
                    border.width: 1
                    border.color: Qt.alpha(Palette.Theme.errorColor, root.confirmChoiceSelected ? 0.55 : 0.25)
                    scale: confirmMouse.pressed ? 0.94 : 1
                    Behavior on scale {
                        SpatialMotion {
                            fast: true
                        }
                    }

                    Behavior on color {
                        ColorMotion {}
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "\ue5ca"
                            color: Palette.Theme.errorColor
                            font.family: Palette.Theme.fontIcons
                            font.weight: Palette.Theme.iconWeight
                            font.pixelSize: Palette.Theme.iconSizeSmall
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: confirmAction
                            color: Palette.Theme.errorColor
                            font.family: Palette.Theme.fontSans
                            font.pixelSize: Palette.Theme.fontSizeXs
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
                    radius: Palette.Theme.radiusSmall
                    // The primary background follows keyboard/mouse focus,
                    // including the X/Cancel choice.
                    color: !root.confirmChoiceSelected ? Palette.Theme.accent : Palette.Theme.surfaceContainerLow
                    scale: cancelMouse.pressed ? 0.94 : 1
                    Behavior on scale {
                        SpatialMotion {
                            fast: true
                        }
                    }

                    Behavior on color {
                        ColorMotion {}
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 2
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "\ue5cd"
                            color: !root.confirmChoiceSelected ? Palette.Theme.accentText : Palette.Theme.textPrimary
                            font.family: Palette.Theme.fontIcons
                            font.weight: Palette.Theme.iconWeight
                            font.pixelSize: Palette.Theme.iconSizeSmall
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Cancel"
                            color: !root.confirmChoiceSelected ? Palette.Theme.accentText : Palette.Theme.textPrimary
                            font.family: Palette.Theme.fontSans
                            font.pixelSize: Palette.Theme.fontSizeXs
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
