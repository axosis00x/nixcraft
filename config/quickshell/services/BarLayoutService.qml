import Quickshell
import Quickshell.Io
import QtQuick

// Persists which edge the bar lives on (top horizontal strip vs. left
// vertical dock) so it survives shell reloads/restarts. Plain data + a
// setter — the actual picker UI (modules/barlayout/BarLayoutPicker.qml,
// opened via IPC target "barlayout") is what decides when to call setVertical.
Item {
    id: root
    visible: false

    readonly property bool vertical: state.vertical

    function setVertical(value) {
        state.vertical = value;
        stateFile.writeAdapter();
        // Keeps Hyprland's workspace-slide direction (vertAni.lua vs
        // horizAni.lua) in sync with the bar's edge.
        applyOrientation.exec([Quickshell.env("HOME") + "/.config/quickshell/scripts/bar-style.sh", value ? "vertical" : "horizontal"]);
    }

    Process {
        id: applyOrientation
    }

    // blockLoading forces the initial read to happen synchronously, so the
    // bar renders with its real saved edge immediately — without it, the
    // bar briefly renders vertical (the declared default below) then snaps
    // to the loaded value a moment later, which is the "wobble" on reload.
    FileView {
        id: stateFile
        path: Quickshell.cachePath("bar-layout.json")
        watchChanges: false
        blockLoading: true

        JsonAdapter {
            id: state
            // Matches the value you had set directly in config/Ui.js before
            // this became a live-toggleable, persisted setting.
            property bool vertical: true
        }
    }
}
