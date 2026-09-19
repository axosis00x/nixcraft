import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../components/material"
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
    property string query: ""
    property int selected: 0
    readonly property var entries: service ? service.entries.filter(entry => entry.text.toLowerCase().indexOf(query.toLowerCase()) !== -1) : []

    implicitWidth: Math.min(maxWidth - 20, Ui.clipboardOverlayWidth)
    implicitHeight: Math.min(maxHeight - 12, 390)

    signal aboutToOpen
    signal aboutToClose

    IpcHandler {
        target: "clipboard"
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
        query = "";
        selected = 0;
        aboutToOpen();
        visible = true;
        service.refresh();
        search.forceActiveFocus();
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
    function copy(index) {
        if (index >= 0 && index < entries.length) {
            service.copy(entries[index].id);
            close();
        }
    }
    function move(delta) {
        if (entries.length)
            selected = Math.max(0, Math.min(entries.length - 1, selected + delta));
    }
    function isBinary(entry) {
        return /^\[\[\s*binary data/i.test(entry.text);
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
            copy(selected);
            event.accepted = true;
        }
    }

    ColumnLayout {
        anchors.fill: parent
            anchors.topMargin: 14
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            anchors.bottomMargin: 22
            spacing: 10
            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Clipboard"
                    color: Palette.Theme.textTitle
                    font.family: Palette.Theme.fontSans
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                }
                Text {
                    text: root.entries.length + " items"
                    color: Palette.Theme.textMuted
                    font.family: Palette.Theme.fontSans
                    font.pixelSize: 11
                }
                ActionChip {
                    label: "Clear"
                    onClicked: root.service.clear()
                }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                Layout.minimumHeight: 46
                Layout.maximumHeight: 46
                radius: 16
                color: Palette.Theme.surfaceContainerHigh
                border.width: search.activeFocus ? 1 : 0
                border.color: Palette.Theme.accent

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 13
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\ue8b6"
                    color: search.activeFocus ? Palette.Theme.accent : Palette.Theme.textMuted
                    font.family: Palette.Theme.fontIcons
                    font.pixelSize: 18
                }
                TextInput {
                    id: search
                    anchors.left: parent.left
                    anchors.leftMargin: 42
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    color: Palette.Theme.textPrimary
                    font.family: Palette.Theme.fontMono
                    font.pixelSize: 13
                    verticalAlignment: TextInput.AlignVCenter
                    selectByMouse: true
                    text: root.query
                    onTextChanged: {
                        root.query = text;
                        root.selected = 0;
                    }
                    Keys.onPressed: function (event) {
                        root.handleKey(event);
                    }
                }
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 42
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !search.text && !search.activeFocus
                    text: "Search clipboard history"
                    color: Palette.Theme.textMuted
                    font.family: Palette.Theme.fontMono
                    font.pixelSize: 13
                }
            }
            GridView {
                id: grid
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                cellWidth: width
                cellHeight: 70
                model: root.entries
                delegate: Item {
                    required property var modelData
                    required property int index
                    width: grid.cellWidth
                    height: grid.cellHeight
                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: 2
                        anchors.bottomMargin: 4
                        radius: 12
                        color: index === root.selected ? Palette.Theme.surfaceContainerHigh : Palette.Theme.surfaceContainerLow
                        border.width: index === root.selected ? 2 : 0
                        border.color: Palette.Theme.accent

                        Behavior on color {
                            ColorAnimation { duration: 120 }
                        }
                        Behavior on border.width {
                            NumberAnimation { duration: 120 }
                        }
                        Rectangle {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            width: 32
                            height: 32
                            radius: 10
                            color: root.isBinary(modelData) ? Palette.Theme.secondaryContainer : Palette.Theme.accentLight
                            Text {
                                anchors.centerIn: parent
                                text: root.isBinary(modelData) ? "\ue2c4" : "\ue14d"
                                color: root.isBinary(modelData) ? Palette.Theme.secondaryText : Palette.Theme.accent
                                font.family: Palette.Theme.fontIcons
                                font.pixelSize: 17
                            }
                        }
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 54
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.top: parent.top
                            anchors.topMargin: 11
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 9
                            text: modelData.text.replace(/\n/g, " ")
                            textFormat: Text.PlainText
                            color: Palette.Theme.textPrimary
                            font.family: Palette.Theme.fontMono
                            font.pixelSize: 11
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: root.selected = index
                            onClicked: root.copy(index)
                        }
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                visible: entries.length === 0
                text: "Clipboard history is empty"
                color: Palette.Theme.textMuted
                font.family: Palette.Theme.fontMono
                font.pixelSize: 10
                horizontalAlignment: Text.AlignHCenter
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
