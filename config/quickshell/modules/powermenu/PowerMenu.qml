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
    property int hoveredIndex: -1
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
        hoveredIndex = -1;
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
                    readonly property bool highlighted: root.hoveredIndex >= 0 ? root.hoveredIndex === index : root.selectedIndex === index

                    Layout.minimumWidth: 48
                    Layout.preferredWidth: 48
                    Layout.maximumWidth: 48
                    implicitHeight: 48
                    radius: Palette.Theme.radiusMedium
                    scale: actionMouse.pressed ? 0.97 : (actionMouse.containsMouse ? 1.04 : 1)
                    Behavior on scale {
                        NumberAnimation {
                            duration: actionMouse.pressed ? Palette.Theme.effectFast : 220
                            easing.type: Easing.OutCubic
                        }
                    }

                    color: {
                        if (modelData.dangerous)
                            return Qt.alpha(Palette.Theme.errorColor, highlighted ? 0.22 : 0.09);
                        return highlighted ? Palette.Theme.accent : Palette.Theme.surfaceContainerHigh;
                    }
                    border.width: modelData.dangerous || actionMouse.containsMouse ? 1 : 0
                    border.color: modelData.dangerous ? Qt.alpha(Palette.Theme.errorColor, highlighted ? 0.55 : 0.25) : Qt.alpha(Palette.Theme.accent, 0.55)

                    Behavior on border.width {
                        NumberAnimation {
                            duration: 180
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on color {
                        ColorMotion {
                            fast: false
                        }
                    }

                    Behavior on border.color {
                        ColorMotion {
                            fast: false
                        }
                    }

                    StateLayer {
                        radius: parent.radius
                        tone: modelData.dangerous ? Palette.Theme.errorColor : (parent.highlighted ? Palette.Theme.accentText : Palette.Theme.textPrimary)
                        hovered: actionMouse.containsMouse
                        pressed: actionMouse.pressed
                    }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.icon
                        color: modelData.dangerous ? Palette.Theme.errorColor : (parent.highlighted ? Palette.Theme.accentText : Palette.Theme.textPrimary)
                        font.family: Palette.Theme.fontIcons
                        font.weight: Palette.Theme.iconWeight
                        font.pixelSize: Palette.Theme.iconSize

                        Behavior on color {
                            ColorMotion {
                                fast: false
                            }
                        }
                    }

                    MouseArea {
                        id: actionMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onContainsMouseChanged: {
                            if (containsMouse) {
                                root.hoveredIndex = index;
                                root.selectedIndex = index;
                            } else if (root.hoveredIndex === index) {
                                root.hoveredIndex = -1;
                            }
                        }
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
                    Behavior on border.color {
                        ColorMotion {
                            fast: false
                        }
                    }
                    scale: confirmMouse.pressed ? 0.98 : (confirmMouse.containsMouse ? 1.015 : 1)
                    Behavior on scale {
                        NumberAnimation {
                            duration: confirmMouse.pressed ? Palette.Theme.effectFast : 180
                            easing.type: Easing.OutCubic
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
                            Behavior on color {
                                ColorMotion {
                                    fast: false
                                }
                            }
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: confirmAction
                            color: Palette.Theme.errorColor
                            font.family: Palette.Theme.fontSans
                            font.pixelSize: Palette.Theme.fontSizeXs
                            font.weight: Font.Medium
                            Behavior on color {
                                ColorMotion {
                                    fast: false
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: confirmMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onContainsMouseChanged: if (containsMouse)
                            root.confirmChoiceSelected = true
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
                    scale: cancelMouse.pressed ? 0.98 : (cancelMouse.containsMouse ? 1.015 : 1)
                    Behavior on scale {
                        NumberAnimation {
                            duration: cancelMouse.pressed ? Palette.Theme.effectFast : 180
                            easing.type: Easing.OutCubic
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
                            Behavior on color {
                                ColorMotion {
                                    fast: false
                                }
                            }
                        }
                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "Cancel"
                            color: !root.confirmChoiceSelected ? Palette.Theme.accentText : Palette.Theme.textPrimary
                            font.family: Palette.Theme.fontSans
                            font.pixelSize: Palette.Theme.fontSizeXs
                            font.weight: Font.Medium
                            Behavior on color {
                                ColorMotion {
                                    fast: false
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: cancelMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onContainsMouseChanged: if (containsMouse)
                            root.confirmChoiceSelected = false
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
