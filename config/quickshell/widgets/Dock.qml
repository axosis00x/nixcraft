pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import "../theme" as Palette

// Bottom-centered app dock: pinned apps plus anything currently running.
// Click focuses (cycling through windows) or launches, right-click opens a
// small menu (pin/unpin, new window, close). On/off is persisted through
// WidgetsService and can be flipped from the launcher's "/widgets" list or
// `quickshell ipc call dock toggle`.
Scope {
    id: root

    property var widgetsService: null

    readonly property bool dockOn: widgetsService ? widgetsService.isEnabled("dock") : false
    readonly property var pinnedIds: widgetsService ? widgetsService.dockPinned : []
    readonly property var items: buildItems(pinnedIds, ToplevelManager.toplevels.values, DesktopEntries.applications.values)

    IpcHandler {
        target: "dock"

        function toggle(): void {
            if (root.widgetsService)
                root.widgetsService.toggle("dock");
        }
        function open(): void {
            if (root.widgetsService && !root.dockOn)
                root.widgetsService.toggle("dock");
        }
        function close(): void {
            if (root.widgetsService && root.dockOn)
                root.widgetsService.toggle("dock");
        }
    }

    function keyOf(s) {
        return (s || "").toLowerCase().replace(/\.desktop$/, "");
    }

    function lookup(id) {
        return DesktopEntries.byId(id) || DesktopEntries.byId(keyOf(id)) || DesktopEntries.heuristicLookup(keyOf(id)) || null;
    }

    function keysFor(entry) {
        var keys = [keyOf(entry.id), keyOf(entry.name)];
        if (entry.startupClass)
            keys.push(keyOf(entry.startupClass));
        return keys;
    }

    function iconFor(entry, fallback) {
        var path = entry && entry.icon ? Quickshell.iconPath(entry.icon, true) : "";
        if (!path && fallback)
            path = Quickshell.iconPath(fallback, true);
        return path || Quickshell.iconPath("application-x-executable", true);
    }

    function makeItem(entry, windows, pinned, fallbackKey) {
        return {
            id: entry ? entry.id : "",
            name: entry ? entry.name : fallbackKey,
            icon: iconFor(entry, fallbackKey),
            entry: entry,
            windows: windows,
            pinned: pinned
        };
    }

    function buildItems(pins, toplevels, apps) {
        var groups = {};
        for (var i = 0; i < toplevels.length; i++) {
            var k = keyOf(toplevels[i].appId);
            if (k === "")
                continue;
            (groups[k] = groups[k] || []).push(toplevels[i]);
        }

        var claimed = {};
        var seen = {};
        var out = [];

        for (var p = 0; p < pins.length; p++) {
            var entry = lookup(pins[p]);
            if (!entry || seen[entry.id])
                continue;
            seen[entry.id] = true;
            var wins = [];
            var keys = keysFor(entry);
            for (var j = 0; j < keys.length; j++) {
                if (groups[keys[j]] && !claimed[keys[j]]) {
                    claimed[keys[j]] = true;
                    wins = wins.concat(groups[keys[j]]);
                }
            }
            out.push(makeItem(entry, wins, true, keyOf(pins[p])));
        }

        for (var key in groups) {
            if (claimed[key])
                continue;
            out.push(makeItem(DesktopEntries.heuristicLookup(key) || null, groups[key], false, key));
        }
        return out;
    }

    function launch(item) {
        if (item.entry)
            item.entry.execute();
    }

    function activate(item) {
        var wins = item.windows;
        if (wins.length === 0) {
            launch(item);
            return;
        }
        var current = -1;
        for (var i = 0; i < wins.length; i++) {
            if (wins[i].activated)
                current = i;
        }
        wins[(current + 1) % wins.length].activate();
    }

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

    Variants {
        model: Quickshell.screens

        delegate: PanelWindow {
            id: win

            required property var modelData

            // 0 → 1 slide/fade so toggling the dock on and off animates
            // instead of popping; the window only stays mapped while the
            // dock is on screen or still animating out.
            property real reveal: root.dockOn ? 1 : 0
            property var menuItem: null

            Behavior on reveal {
                NumberAnimation {
                    duration: 260
                    easing.type: Easing.OutCubic
                }
            }

            screen: modelData
            visible: (root.dockOn || reveal > 0.001) && root.items.length > 0
            color: "transparent"
            exclusiveZone: 0
            exclusionMode: ExclusionMode.Ignore
            // Tall enough for the context menu (header + 3 rows) to sit
            // fully above the dock without being clipped by the window.
            implicitHeight: 260

            anchors {
                left: true
                right: true
                bottom: true
            }

            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "quickshell:dock"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            // Input is limited to the dock (with headroom for the hover
            // magnification) and the context menu; everything else in this
            // full-width strip passes straight through to the windows below.
            mask: Region {
                Region {
                    item: hitBox
                    intersection: Intersection.Combine
                }
                Region {
                    item: menu.visible ? menu : null
                    intersection: Intersection.Combine
                }
            }

            Timer {
                id: menuCloseTimer
                interval: 700
                onTriggered: win.menuItem = null
            }

            Item {
                id: hitBox
                x: dock.x - 8
                y: dock.y - 18
                width: dock.width + 16
                height: win.height - y

                HoverHandler {
                    id: dockHover
                    onHoveredChanged: {
                        if (!hovered && win.menuItem)
                            menuCloseTimer.restart();
                        else
                            menuCloseTimer.stop();
                    }
                }
            }

            Rectangle {
                id: dock

                readonly property real cell: 44

                width: row.implicitWidth + 20
                height: cell + 20
                radius: 22
                color: Palette.Theme.surfaceContainer
                border.width: 1
                border.color: Palette.Theme.outlineVariant
                opacity: win.reveal
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height - height - 12 + (1 - win.reveal) * (height + 24)

                Behavior on width {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }

                Row {
                    id: row
                    anchors.centerIn: parent
                    spacing: 6

                    Repeater {
                        model: root.items

                        delegate: Item {
                            id: cell

                            required property var modelData

                            readonly property var wins: modelData.windows
                            readonly property bool running: wins.length > 0
                            readonly property bool hovered: mouse.containsMouse
                            readonly property bool focused: {
                                for (var i = 0; i < wins.length; i++) {
                                    if (wins[i].activated)
                                        return true;
                                }
                                return false;
                            }

                            width: dock.cell
                            height: dock.cell
                            scale: 0.6
                            opacity: 0

                            Component.onCompleted: {
                                scale = 1;
                                opacity = 1;
                            }

                            Behavior on scale {
                                NumberAnimation {
                                    duration: 260
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 1.6
                                }
                            }
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 160
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: 14
                                color: cell.focused ? Palette.Theme.surfaceContainerHighest : (cell.hovered ? Palette.Theme.surfaceContainerHigh : "transparent")

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                    }
                                }
                            }

                            IconImage {
                                id: icon
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: -2
                                implicitSize: 30
                                source: cell.modelData.icon
                                smooth: true
                                mipmap: true
                                transformOrigin: Item.Bottom
                                scale: cell.hovered ? 1.28 : 1

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: 180
                                        easing.type: Easing.OutBack
                                        easing.overshoot: 1.6
                                    }
                                }
                            }

                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 3
                                height: 3
                                radius: 2
                                width: cell.focused ? 14 : (cell.running ? 5 : 0)
                                color: cell.focused ? Palette.Theme.accent : Palette.Theme.textMuted

                                Behavior on width {
                                    NumberAnimation {
                                        duration: 160
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }

                            Rectangle {
                                visible: cell.hovered && win.menuItem === null
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.top
                                anchors.bottomMargin: 18
                                width: tipText.implicitWidth + 20
                                height: 26
                                radius: 13
                                color: Palette.Theme.surfaceContainerHigh
                                border.width: 1
                                border.color: Palette.Theme.outlineVariant

                                Text {
                                    id: tipText
                                    anchors.centerIn: parent
                                    text: cell.modelData.name
                                    color: Palette.Theme.textPrimary
                                    font.family: Palette.Theme.fontMono
                                    font.pixelSize: 11
                                }
                            }

                            MouseArea {
                                id: mouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: event => {
                                    if (event.button === Qt.RightButton) {
                                        win.menuItem = win.menuItem === cell.modelData ? null : cell.modelData;
                                        var p = cell.mapToItem(win.contentItem, cell.width / 2, 0);
                                        menu.anchorX = p.x;
                                    } else if (event.button === Qt.MiddleButton) {
                                        root.launch(cell.modelData);
                                    } else {
                                        win.menuItem = null;
                                        root.activate(cell.modelData);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: menu

                property real anchorX: 0
                readonly property var item: win.menuItem

                visible: item !== null
                width: 184
                height: menuColumn.implicitHeight + 16
                radius: 14
                color: Palette.Theme.surfaceContainerHigh
                border.width: 1
                border.color: Palette.Theme.outlineVariant
                x: Math.max(8, Math.min(win.width - width - 8, anchorX - width / 2))
                y: Math.max(4, dock.y - height - 12)
                z: 10

                HoverHandler {
                    onHoveredChanged: {
                        if (hovered)
                            menuCloseTimer.stop();
                        else if (win.menuItem)
                            menuCloseTimer.restart();
                    }
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
                            root.launch(menu.item);
                            win.menuItem = null;
                        }
                    }

                    MenuRow {
                        width: parent.width
                        visible: menu.item !== null && menu.item.id !== ""
                        height: visible ? implicitHeight : 0
                        label: menu.item && menu.item.pinned ? "Unpin from dock" : "Pin to dock"
                        onTriggered: {
                            if (root.widgetsService && menu.item)
                                root.widgetsService.togglePin(menu.item.id);
                            win.menuItem = null;
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
                            win.menuItem = null;
                        }
                    }
                }
            }
        }
    }
}
