import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../config/Ui.js" as Ui
import "../../theme" as Palette

Item {
    id: root
    anchors.fill: parent
    visible: false
    focus: visible

    required property var service
    property real maxWidth: 4000
    property real maxHeight: 4000
    property var launcher: null
    property var controlCenter: null
    property var powerMenu: null
    property string query: ""
    property int selected: 0
    readonly property var themes: service ? service.themes.filter(name => name.toLowerCase().indexOf(query.toLowerCase()) !== -1) : []

    implicitWidth: Math.min(maxWidth - 20, Ui.themeOverlayWidth)
    implicitHeight: Math.min(maxHeight - 12, content.implicitHeight + 24)

    signal aboutToOpen
    signal aboutToClose

    IpcHandler {
        target: "theme"
        function toggle(): void {
            root.visible ? root.close() : root.open();
        }
        function open(): void {
            root.open();
        }
        function close(): void {
            root.close();
        }
    }

    function open() {
        if (launcher && launcher.visible)
            launcher.closeLauncher(true);
        if (controlCenter && controlCenter.visible)
            controlCenter.closeControlCenter(true);
        if (powerMenu && powerMenu.visible)
            powerMenu.closePowerMenu(true);
        query = "";
        selected = 0;
        aboutToOpen();
        visible = true;
        service.refresh();
        forceActiveFocus();
    }

    function close(immediate) {
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

    function apply(index) {
        if (index < 0 || index >= themes.length)
            return;
        service.apply(themes[index]);
        close();
    }

    function move(delta) {
        if (themes.length === 0)
            return;
        selected = Math.max(0, Math.min(themes.length - 1, selected + delta));
    }

    function accentFor(themeName) {
        var colors = {
            gruvbox: "#d79921",
            mocha: "#cba6f7",
            monochrome: "#d0d0d0",
            moonfly: "#78a8ff",
            ryo: "#8bd5ff",
            tokyonight: "#7aa2f7"
        };
        return colors[themeName] || Palette.Theme.accent;
    }

    function handleKey(event) {
        if (event.key === Qt.Key_Escape) {
            close();
            event.accepted = true;
        } else if (event.key === Qt.Key_Left) {
            move(-1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Right) {
            move(1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            move(-3);
            event.accepted = true;
        } else if (event.key === Qt.Key_Down) {
            move(3);
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            apply(selected);
            event.accepted = true;
        }
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Theme"
                    color: Palette.Theme.textTitle
                    font.family: Palette.Theme.fontMono
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                }
                Text {
                    text: service.activeTheme
                    color: Palette.Theme.textMuted
                    font.family: Palette.Theme.fontMono
                    font.pixelSize: 11
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            GridLayout {
                columns: 3
                columnSpacing: 10
                rowSpacing: 10
                Layout.fillWidth: true

                Repeater {
                    model: root.themes
                    delegate: Rectangle {
                        id: card
                        required property string modelData
                        required property int index
                        readonly property bool isActive: modelData === service.activeTheme
                        Layout.fillWidth: true
                        Layout.preferredHeight: 92
                        radius: 14
                        scale: cardMouse.pressed ? 0.94 : (cardMouse.containsMouse || index === root.selected ? 1.025 : 1.0)
                        Behavior on scale {
                            NumberAnimation {
                                duration: 150
                                easing.type: Easing.OutBack
                                easing.overshoot: 1.4
                            }
                        }
                        color: index === root.selected ? Palette.Theme.surfaceContainerHigh : Palette.Theme.surfaceContainerLow
                        border.width: index === root.selected ? 2 : 0
                        border.color: root.accentFor(modelData)

                        Behavior on border.width {
                            NumberAnimation {
                                duration: 110
                            }
                        }
                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }

                        Row {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.margins: 14
                            spacing: 6

                            Repeater {
                                model: 4
                                delegate: Rectangle {
                                    required property int index
                                    width: 16
                                    height: 16
                                    radius: 5
                                    color: root.accentFor(card.modelData)
                                    opacity: 1 - index * 0.24
                                }
                            }
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 14
                            text: modelData.replace(/-/g, " ")
                            color: Palette.Theme.textPrimary
                            font.family: Palette.Theme.fontSans
                            font.pixelSize: 12
                            font.weight: index === root.selected ? Font.DemiBold : Font.Medium
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 10
                            width: 18
                            height: 18
                            radius: 9
                            visible: card.isActive
                            color: root.accentFor(card.modelData)

                            Text {
                                anchors.centerIn: parent
                                text: "✓"
                                color: Palette.Theme.bg
                                font.pixelSize: 10
                                font.bold: true
                            }
                        }

                        MouseArea {
                            id: cardMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.selected = index
                            onClicked: root.apply(index)
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
    Keys.onPressed: function (event) {
        root.handleKey(event);
    }
}
