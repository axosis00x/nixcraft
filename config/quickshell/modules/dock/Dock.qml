pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import "../../theme" as Palette

// The bottom notch's resting state: pinned apps plus anything currently
// running. Hosted by the bottom stage in components/overlay/CenterOverlay.qml,
// so the slab morphs between this and the launcher / pickers exactly like
// those morph between each other. Tooltip and context menu are drawn by
// DockPopups (outside the notch, which clips its content).
Item {
    id: root

    anchors.fill: parent
    visible: false

    property var widgetsService: null
    property real maxWidth: 4000

    readonly property bool dockOn: widgetsService ? widgetsService.isEnabled("dock") : false
    readonly property var pinnedIds: widgetsService ? widgetsService.dockPinned : []
    readonly property var items: buildItems(pinnedIds, ToplevelManager.toplevels.values, DesktopEntries.applications.values)

    readonly property bool fullscreenActive: ToplevelManager.activeToplevel ? ToplevelManager.activeToplevel.fullscreen : false
    // Whether the stage should show the dock when nothing else is open.
    readonly property bool wanted: dockOn && items.length > 0 && !fullscreenActive

    // Shared with DockPopups.
    property Item hoverCell: null
    property var hoverItem: null
    property var menuItem: null
    property Item menuCell: null

    readonly property real cellSize: 40
    readonly property real cellSpacing: 6

    implicitWidth: Math.min(maxWidth - 40, row.implicitWidth + 30)
    implicitHeight: cellSize + 14

    onVisibleChanged: {
        if (!visible)
            closeMenu();
    }

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
        if (item && item.entry)
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

    function closeMenu() {
        menuItem = null;
        menuCell = null;
        hoverCell = null;
        hoverItem = null;
        menuCloseTimer.stop();
    }

    // Drag-to-reorder for pinned apps. Pinned items always come first in
    // `items`, so a pinned item's index is also its slot in the pin order.
    property int dragIndex: -1
    property int dropIndex: -1
    // Off briefly after a reorder so the rebuilt delegates don't replay their
    // pop-in animation.
    property bool popIn: true

    readonly property int pinnedCount: {
        var n = 0;
        for (var i = 0; i < items.length; i++) {
            if (items[i].pinned)
                n++;
        }
        return n;
    }

    Timer {
        id: popInTimer
        interval: 450
        onTriggered: root.popIn = true
    }

    function commitReorder(from, to) {
        if (!widgetsService || from === to || from < 0 || to < 0)
            return;
        var ids = [];
        for (var i = 0; i < pinnedCount; i++)
            ids.push(items[i].id);
        var moved = ids.splice(from, 1)[0];
        ids.splice(to, 0, moved);
        // Keep pins whose app isn't installed/resolvable right now.
        var rest = pinnedIds.filter(p => !lookup(p));
        popIn = false;
        popInTimer.restart();
        widgetsService.setPinOrder(ids.concat(rest));
    }

    Timer {
        id: menuCloseTimer
        interval: 700
        onTriggered: root.closeMenu()
    }

    // Lets DockPopups keep the menu open while the pointer is over it.
    function holdMenu(hold) {
        if (hold)
            menuCloseTimer.stop();
        else if (menuItem)
            menuCloseTimer.restart();
    }

    HoverHandler {
        onHoveredChanged: root.holdMenu(hovered)
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: root.cellSpacing

        Repeater {
            model: root.items

            delegate: Item {
                id: cell

                required property var modelData
                required property int index

                readonly property var wins: modelData.windows
                readonly property bool running: wins.length > 0
                readonly property bool dragging: root.dragIndex === index
                readonly property bool hovered: mouse.containsMouse && root.dragIndex < 0
                readonly property bool focused: {
                    for (var i = 0; i < wins.length; i++) {
                        if (wins[i].activated)
                            return true;
                    }
                    return false;
                }

                // Slides neighbours aside to open a gap at the drop slot.
                readonly property real shiftX: {
                    var step = root.cellSize + root.cellSpacing;
                    if (root.dragIndex < 0 || dragging || !modelData.pinned)
                        return 0;
                    if (root.dragIndex < root.dropIndex && index > root.dragIndex && index <= root.dropIndex)
                        return -step;
                    if (root.dragIndex > root.dropIndex && index >= root.dropIndex && index < root.dragIndex)
                        return step;
                    return 0;
                }
                property real dragX: 0

                width: root.cellSize
                height: root.cellSize
                z: dragging ? 10 : 0

                onHoveredChanged: {
                    if (hovered) {
                        root.hoverCell = cell;
                        root.hoverItem = modelData;
                    } else if (root.hoverCell === cell) {
                        root.hoverCell = null;
                        root.hoverItem = null;
                    }
                }

                Item {
                    id: tile

                    width: parent.width
                    height: parent.height
                    x: cell.dragging ? cell.dragX : cell.shiftX
                    scale: root.popIn ? 0.6 : 1
                    opacity: root.popIn ? 0 : 1

                    Component.onCompleted: {
                        scale = 1;
                        opacity = 1;
                    }

                    Behavior on x {
                        enabled: !cell.dragging
                        NumberAnimation {
                            duration: 200
                            easing.type: Easing.OutCubic
                        }
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

                    IconImage {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -2
                        implicitSize: 28
                        source: cell.modelData.icon
                        smooth: true
                        mipmap: true
                        transformOrigin: Item.Bottom
                        scale: cell.dragging ? 1.15 : (cell.hovered ? 1.28 : 1)

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
                        anchors.bottomMargin: 2
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
                }

                // Covers the (stationary) slot rather than the tile, so pointer
                // coordinates stay stable while the tile itself is being dragged.
                MouseArea {
                    id: mouse

                    property real pressX: 0
                    property bool moved: false

                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    cursorShape: cell.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor

                    onPressed: event => {
                        pressX = event.x;
                        moved = false;
                    }

                    onPositionChanged: event => {
                        if (!(pressedButtons & Qt.LeftButton) || !cell.modelData.pinned)
                            return;
                        var dx = event.x - pressX;
                        if (!cell.dragging) {
                            if (Math.abs(dx) < 8)
                                return;
                            root.closeMenu();
                            root.dragIndex = cell.index;
                            root.dropIndex = cell.index;
                            moved = true;
                        }
                        var step = root.cellSize + root.cellSpacing;
                        var lo = -cell.index * step;
                        var hi = (root.pinnedCount - 1 - cell.index) * step;
                        cell.dragX = Math.max(lo, Math.min(hi, dx));
                        root.dropIndex = Math.max(0, Math.min(root.pinnedCount - 1, Math.round(cell.index + cell.dragX / step)));
                    }

                    onReleased: {
                        if (cell.dragging) {
                            var from = root.dragIndex;
                            var to = root.dropIndex;
                            root.dragIndex = -1;
                            root.dropIndex = -1;
                            cell.dragX = 0;
                            root.commitReorder(from, to);
                        }
                    }

                    onClicked: event => {
                        if (moved)
                            return;
                        if (event.button === Qt.RightButton) {
                            if (root.menuItem === cell.modelData) {
                                root.closeMenu();
                            } else {
                                root.menuItem = cell.modelData;
                                root.menuCell = cell;
                            }
                        } else if (event.button === Qt.MiddleButton) {
                            root.launch(cell.modelData);
                        } else {
                            root.closeMenu();
                            root.activate(cell.modelData);
                        }
                    }
                }
            }
        }
    }
}
