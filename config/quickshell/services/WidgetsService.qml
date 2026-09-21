import Quickshell
import Quickshell.Io
import QtQuick

// Enable/disable + on-screen position for the desktop widget layer
// (widgets/DesktopWidgetsLayer.qml), persisted the same way BarLayoutService
// persists the bar edge. The enable/disable picker UI lives in the
// launcher's "/widgets" command (modules/launcher/Launcher.qml); position is
// set by dragging the widgets themselves.
Item {
    id: root
    visible: false

    readonly property var widgets: [
        { id: "clock", label: "Clock Widget", icon: "" },
        { id: "weather", label: "Weather Widget", icon: "" },
        { id: "dock", label: "Dock", icon: "" }
    ]

    // Desktop-file ids pinned to the dock (widgets/Dock.qml), in order.
    readonly property var dockPinned: state.dockPinned

    function isPinned(appId) {
        return state.dockPinned.indexOf(appId) !== -1;
    }

    function setPinOrder(ids) {
        state.dockPinned = ids;
        stateFile.writeAdapter();
    }

    function togglePin(appId) {
        if (!appId)
            return;
        var next = state.dockPinned.slice();
        var i = next.indexOf(appId);
        if (i === -1)
            next.push(appId);
        else
            next.splice(i, 1);
        state.dockPinned = next;
        stateFile.writeAdapter();
    }

    function isEnabled(widgetId) {
        switch (widgetId) {
        case "clock":
            return state.clockEnabled;
        case "weather":
            return state.weatherEnabled;
        case "dock":
            return state.dockEnabled;
        default:
            return false;
        }
    }

    function toggle(widgetId) {
        switch (widgetId) {
        case "clock":
            state.clockEnabled = !state.clockEnabled;
            break;
        case "weather":
            state.weatherEnabled = !state.weatherEnabled;
            break;
        case "dock":
            state.dockEnabled = !state.dockEnabled;
            break;
        }
        stateFile.writeAdapter();
    }

    // A negative coordinate means "never dragged" — the widget falls back
    // to its default corner layout instead.
    function hasPosition(widgetId) {
        switch (widgetId) {
        case "clock":
            return state.clockX >= 0 && state.clockY >= 0;
        case "weather":
            return state.weatherX >= 0 && state.weatherY >= 0;
        default:
            return false;
        }
    }

    function positionX(widgetId) {
        switch (widgetId) {
        case "clock":
            return state.clockX;
        case "weather":
            return state.weatherX;
        default:
            return 0;
        }
    }

    function positionY(widgetId) {
        switch (widgetId) {
        case "clock":
            return state.clockY;
        case "weather":
            return state.weatherY;
        default:
            return 0;
        }
    }

    function setPosition(widgetId, x, y) {
        switch (widgetId) {
        case "clock":
            state.clockX = x;
            state.clockY = y;
            break;
        case "weather":
            state.weatherX = x;
            state.weatherY = y;
            break;
        }
        stateFile.writeAdapter();
    }

    // blockLoading forces the initial read to happen synchronously, so
    // isEnabled()/hasPosition() etc. see the real saved state on the very
    // first render instead of the declared defaults below flashing first.
    FileView {
        id: stateFile
        path: Quickshell.cachePath("desktop-widgets.json")
        watchChanges: false
        blockLoading: true

        JsonAdapter {
            id: state
            property bool clockEnabled: true
            property bool weatherEnabled: true
            property bool dockEnabled: true
            property var dockPinned: ["kitty", "zen-twilight", "org.gnome.Nautilus", "dev.zed.Zed", "spotify"]
            property real clockX: -1
            property real clockY: -1
            property real weatherX: -1
            property real weatherY: -1
        }
    }
}
