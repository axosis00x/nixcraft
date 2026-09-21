import QtQuick
import "../../theme" as Palette

// Hover label and right-click menu for the dock. Lives at the overlay root
// rather than inside the bottom notch because the notch clips its content;
// positions are derived from the dock's hovered / menu cell.
Item {
    id: root

    required property var dock

    anchors.fill: parent

    readonly property bool menuVisible: dock.visible && dock.menuItem !== null && dock.menuCell !== null
    readonly property alias menuRect: menu

    readonly property point hoverPoint: dock.hoverCell ? dock.hoverCell.mapToItem(root, dock.hoverCell.width / 2, 0) : Qt.point(0, 0)
    readonly property point menuPoint: dock.menuCell ? dock.menuCell.mapToItem(root, dock.menuCell.width / 2, 0) : Qt.point(0, 0)

    component MenuRow: Rectangle {
        id: row

        property string label: ""
        signal triggered

        implicitWidth: 168
        implicitHeight: 30
        radius: 9
        color: rowMouse.containsMouse ? Palette.Theme.surfaceContainerHighest : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: 100
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 10
            text: row.label
            color: Palette.Theme.textPrimary
            font.family: Palette.Theme.fontMono
            font.pixelSize: 11
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.triggered()
        }
    }

    Rectangle {
        id: tip

        visible: root.dock.visible && root.dock.hoverItem !== null && !root.menuVisible
        width: tipText.implicitWidth + 20
        height: 26
        radius: 13
        x: Math.max(6, Math.min(root.width - width - 6, root.hoverPoint.x - width / 2))
        y: root.hoverPoint.y - height - 16
        color: Palette.Theme.surfaceContainer
        border.width: 1
        border.color: Palette.Theme.outlineVariant

        Text {
            id: tipText
            anchors.centerIn: parent
            text: root.dock.hoverItem ? root.dock.hoverItem.name : ""
            color: Palette.Theme.textPrimary
            font.family: Palette.Theme.fontMono
            font.pixelSize: 11
        }
    }

    Rectangle {
        id: menu

        readonly property var item: root.dock.menuItem

        visible: root.menuVisible
        width: 184
        height: menuColumn.implicitHeight + 16
        radius: 14
        x: Math.max(6, Math.min(root.width - width - 6, root.menuPoint.x - width / 2))
        y: Math.max(4, root.menuPoint.y - height - 16)
        color: Palette.Theme.surfaceContainer
        border.width: 1
        border.color: Palette.Theme.outlineVariant

        HoverHandler {
            onHoveredChanged: root.dock.holdMenu(hovered)
        }

        Column {
            id: menuColumn
            anchors.fill: parent
            anchors.margins: 8
            spacing: 2

            Text {
                width: parent.width
                leftPadding: 10
                bottomPadding: 4
                text: menu.item ? menu.item.name : ""
                color: Palette.Theme.textMuted
                font.family: Palette.Theme.fontMono
                font.pixelSize: 10
                elide: Text.ElideRight
            }

            MenuRow {
                width: parent.width
                visible: menu.item !== null && menu.item.windows.length > 0 && menu.item.entry !== null
                height: visible ? implicitHeight : 0
                label: "New window"
                onTriggered: {
                    root.dock.launch(menu.item);
                    root.dock.closeMenu();
                }
            }

            MenuRow {
                width: parent.width
                visible: menu.item !== null && menu.item.id !== ""
                height: visible ? implicitHeight : 0
                label: menu.item && menu.item.pinned ? "Unpin from dock" : "Pin to dock"
                onTriggered: {
                    if (root.dock.widgetsService && menu.item)
                        root.dock.widgetsService.togglePin(menu.item.id);
                    root.dock.closeMenu();
                }
            }

            MenuRow {
                width: parent.width
                visible: menu.item !== null && menu.item.windows.length > 0
                height: visible ? implicitHeight : 0
                label: menu.item && menu.item.windows.length > 1 ? "Close all windows" : "Close window"
                onTriggered: {
                    if (menu.item) {
                        for (var i = 0; i < menu.item.windows.length; i++)
                            menu.item.windows[i].close();
                    }
                    root.dock.closeMenu();
                }
            }
        }
    }
}
