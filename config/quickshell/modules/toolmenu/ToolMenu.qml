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
    property var bar: null
    property int selectedIndex: 0
    property int hoveredIndex: -1

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
            command: ["bash", "-lc", "~/.config/quickshell/scripts/screenshot.sh rc"]
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
            launcher.closeLauncher();
        if (controlCenter && controlCenter.visible && typeof controlCenter.closeControlCenter === "function")
            controlCenter.closeControlCenter();
        if (visible && !closing)
            return;
        selectedIndex = 0;
        hoveredIndex = -1;
        closeTimer.stop();
        aboutToOpen();
        visible = true;
        forceActiveFocus();
    }

    function closeToolMenu(immediate) {
        if (!visible)
            return;
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

    function toggleToolMenu() {
        if (visible && !closing)
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
                    readonly property bool recordAction: modelData.name === "Record"
                    readonly property bool recording: recordAction && root.bar && root.bar.isRecording
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

                    color: highlighted ? Palette.Theme.accent : Palette.Theme.surfaceContainerHigh
                    border.width: recording || actionMouse.containsMouse ? 1 : 0
                    border.color: recording ? Palette.Theme.errorColor : Qt.alpha(Palette.Theme.accent, 0.55)

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
                        tone: highlighted ? Palette.Theme.accentText : Palette.Theme.textPrimary
                        hovered: actionMouse.containsMouse
                        pressed: actionMouse.pressed
                    }

                    Text {
                        anchors.centerIn: parent
                        text: modelData.icon
                        color: recording || parent.highlighted ? Palette.Theme.accentText : Palette.Theme.textPrimary
                        font.family: Palette.Theme.fontIcons
                        font.weight: Palette.Theme.iconWeight
                        font.pixelSize: Palette.Theme.iconSize

                        Behavior on color {
                            ColorMotion {
                                fast: false
                            }
                        }
                    }

                    Rectangle {
                        visible: recording
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.rightMargin: 3
                        anchors.topMargin: 3
                        width: 8
                        height: 8
                        radius: width / 2
                        color: Palette.Theme.errorColor
                        border.width: 1
                        border.color: Palette.Theme.surfaceContainer

                        SequentialAnimation on opacity {
                            running: recording
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.25; duration: 650; easing.type: Easing.InOutSine }
                            NumberAnimation { to: 1; duration: 650; easing.type: Easing.InOutSine }
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
    }

    Timer {
        id: closeTimer
        interval: 180
        onTriggered: root.visible = false
    }
}
