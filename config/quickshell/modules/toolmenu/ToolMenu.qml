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

    implicitWidth: Math.min(maxWidth - 24, actions.length * 48 + (actions.length - 1) * 8 + 16)
    implicitHeight: content.implicitHeight + 16

    signal aboutToOpen
    signal aboutToClose

    readonly property var actions: [
        {
            name: "Color Picker",
            icon: "",
            command: ["bash", "-lc", "~/.config/quickshell/scripts/screenshot.sh p"]
        },
        {
            name: "Screenshot",
            icon: "",
            command: ["bash", "-lc", "~/.config/quickshell/scripts/screenshot.sh ri"]
        },
        {
            name: "Calendar",
            icon: "",
            command: ["qs", "ipc", "call", "calendar", "toggle"]
        },
        {
            name: "Clipboard",
            icon: "",
            command: ["qs", "ipc", "call", "clipboard", "toggle"]
        },
        {
            name: "Record",
            icon: "\u{e061}",
            command: ["bash", "-lc", "~/.config/quickshell/scripts/record.sh"]
        }
    ]

    IpcHandler {
        target: "toolmenu"
        function toggle(): void {
            root.toggleToolMenu();
        }
        function open(): void {
            root.openToolMenu();
        }
        function close(): void {
            root.closeToolMenu();
        }
    }

    function openToolMenu() {
        if (launcher && launcher.visible && typeof launcher.closeLauncher === "function")
            launcher.closeLauncher(true);
        if (controlCenter && controlCenter.visible && typeof controlCenter.closeControlCenter === "function")
            controlCenter.closeControlCenter(true);
        if (visible)
            return;
        selectedIndex = 0;
        aboutToOpen();
        visible = true;
        forceActiveFocus();
    }

    function closeToolMenu(immediate) {
        if (!visible)
            return;
        aboutToClose();
        if (immediate) {
            closeTimer.stop();
            visible = false;
            return;
        }
        closeTimer.restart();
    }

    function toggleToolMenu() {
        if (visible)
            closeToolMenu();
        else
            openToolMenu();
    }

    property var pendingCommand: null

    function choose(index) {
        var action = actions[index];
        closeToolMenu(true);
        // grim/slurp/hyprpicker need to grab keyboard/pointer input, which
        // only becomes available once the compositor has actually unmapped
        // this layer surface -- that happens a frame after `visible = false`,
        // not in this same tick. Defer the launch so the grab doesn't race
        // this panel's own teardown.
        pendingCommand = action.command;
        launchTimer.restart();
    }

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            event.accepted = true;
            closeToolMenu();
        } else if (event.key === Qt.Key_Left) {
            event.accepted = true;
            selectedIndex = (selectedIndex + actions.length - 1) % actions.length;
        } else if (event.key === Qt.Key_Right) {
            event.accepted = true;
            selectedIndex = (selectedIndex + 1) % actions.length;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            event.accepted = true;
            choose(selectedIndex);
        }
    }

    Process {
        id: actionProcess
    }

    Timer {
        id: launchTimer
        interval: 80
        repeat: false
        onTriggered: actionProcess.exec(root.pendingCommand)
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 8
        spacing: 6

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

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

                    color: index === root.selectedIndex ? Palette.Theme.accent : (actionMouse.containsMouse ? Palette.Theme.surfaceContainerHighest : Palette.Theme.surfaceContainerLow)
                    border.width: 0

                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: index === root.selectedIndex ? "#ffffff" : Palette.Theme.accent
                        opacity: actionMouse.pressed ? 0.18 : (actionMouse.containsMouse ? 0.08 : 0)
                        Behavior on opacity {
                            NumberAnimation {
                                duration: 120
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.icon
                        color: index === root.selectedIndex ? Palette.Theme.accentText : Palette.Theme.textPrimary
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
    }

    Timer {
        id: closeTimer
        interval: 180
        onTriggered: root.visible = false
    }
}
