pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

Item {
    id: root
    visible: false

    readonly property int slotCount: 10

    property bool active: false
    // 0-based; the Hyprland workspace id for a slot is index + 1, matching
    // the SUPER+1..0 keybinds in keybinds.lua.
    property int selected: 0

    // Workspace id -> HyprlandWorkspace, rebuilt as workspaces are created
    // (on first use) or destroyed (once emptied). Missing ids just mean an
    // empty slot.
    property var workspacesById: ({})

    function workspaceFor(id) {
        return root.workspacesById[id] || null;
    }

    // ALT+TAB / ALT+SHIFT+TAB call this on every press; the first press opens
    // the overview already parked on the current workspace.
    function step(delta) {
        if (!root.active) {
            root.active = true;
            var current = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1;
            root.selected = Math.max(0, Math.min(root.slotCount - 1, current - 1));
            return;
        }
        root.selected = (root.selected + delta + root.slotCount) % root.slotCount;
    }

    function selectIndex(index) {
        if (index < 0 || index >= root.slotCount)
            return;
        root.selected = index;
    }

    // Bar dots call this directly: unlike step(), which always moves
    // relative to whatever's currently focused, this opens the overview
    // already parked on the exact workspace that was clicked.
    function openAt(index) {
        root.selectIndex(index);
        root.active = true;
    }

    // Bound to releasing ALT, which is what actually commits the selection.
    function confirm() {
        if (root.active)
            root.focusWorkspace(root.selected + 1);
        root.active = false;
    }

    function cancel() {
        root.active = false;
    }

    // Quickshell's Hyprland.dispatch() sends the classic "dispatch <name>
    // <args>" request, but this config runs Hyprland's native Lua parser,
    // which routes hyprctl dispatch through an `hl.dispatch(hl.dsp...)` Lua
    // eval bridge instead and rejects the old string form. Go through
    // `hyprctl eval` directly so these actually take effect.
    function focusWorkspace(id) {
        dispatchProcess.command = ["hyprctl", "eval", "hl.dispatch(hl.dsp.focus({workspace = " + id + "}))"];
        dispatchProcess.running = true;
    }

    // Used by the overview's drag-and-drop: dropping a window's thumbnail
    // onto another slot moves that window there without following it.
    function moveWindowToWorkspace(address, id) {
        var addr = address.indexOf("0x") === 0 ? address : "0x" + address;
        dispatchProcess.command = ["hyprctl", "eval", "hl.dispatch(hl.dsp.window.move({workspace = " + id + ", window = \"address:" + addr + "\"}))"];
        dispatchProcess.running = true;
    }

    Process {
        id: dispatchProcess
    }

    Instantiator {
        model: Hyprland.workspaces

        delegate: Item {
            id: entry
            required property var modelData

            function sync() {
                var next = Object.assign({}, root.workspacesById);
                next[entry.modelData.id] = entry.modelData;
                root.workspacesById = next;
            }

            Component.onCompleted: entry.sync()

            Connections {
                target: entry.modelData
                function onIdChanged() {
                    entry.sync();
                }
            }
        }

        onObjectRemoved: (index, object) => {
            var next = Object.assign({}, root.workspacesById);
            delete next[object.modelData.id];
            root.workspacesById = next;
        }
    }
}
