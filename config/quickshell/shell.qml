//@ pragma DropExpensiveFonts
import Quickshell
import Quickshell.Io
import QtQuick
import "modules/bar"
import "components/overlay"
import "modules/notification"
import "modules/osd"
import "modules/workspaces"
import "modules/lockscreen"
import "modules/idle"
import "services"
import "widgets"

ShellRoot {
    id: root
    NotificationCenter {
        id: notificationCenter
    }
    BarLayoutService {
        id: barLayoutService
    }
    WidgetsService {
        id: widgetsService
    }
    DesktopWidgetsLayer {
        widgetsService: widgetsService
    }
    CenterOverlay {
        id: overlay
        notificationCenter: notificationCenter
        bar: barLoader.item
        idleService: idleService
        barLayout: barLayoutService
        widgetsService: widgetsService
    }
    WorkspacesService {
        id: workspacesServiceInstance
    }
    WorkspaceOverview {
        id: workspaceOverview
        service: workspacesServiceInstance
    }
    Osd {
        id: mainOsd
    }
    LockScreen {
        id: lockScreen
    }
    IdleService {
        id: idleService
        lockScreen: lockScreen
    }
    IpcHandler {
        target: "controlcenter"
        function toggle(): void {
            root.toggleControlCenter();
        }
        function open(): void {
            root.openControlCenter();
        }
        function close(): void {
            root.closeControlCenter();
        }
    }
    function openControlCenter() {
        if (overlay.controlCenter)
            overlay.controlCenter.openControlCenter();
    }
    function closeControlCenter() {
        if (overlay.controlCenter)
            overlay.controlCenter.closeControlCenter();
    }
    function toggleControlCenter() {
        if (overlay.controlCenter)
            overlay.controlCenter.toggleControlCenter();
    }
    IpcHandler {
        target: "mediapanel"
        function toggle(): void {
            root.toggleMediaPanel();
        }
    }
    function toggleMediaPanel() {
        if (overlay.mediaPanel)
            overlay.mediaPanel.toggleMediaPanel();
    }
    IpcHandler {
        target: "shell"
        function reload(): void {
            Quickshell.reload(false);
        }
    }
    // Deferred behind barLayoutService.loaded: BarLayoutService's persisted
    // "vertical" value briefly holds its declared default before the
    // JSON file underneath it actually resolves, and the bar's anchors bind
    // to that value directly with no QML Behavior to smooth it over — so a
    // wrong-then-right flip on reload isn't an animation to suppress, it's
    // the compositor reacting to two real geometry changes. Not
    // constructing the bar at all until the real value is in means it only
    // ever gets built once, with the right one.
    Loader {
        id: barLoader
        active: barLayoutService.loaded

        sourceComponent: Bar {
            osd: mainOsd
            barLayout: barLayoutService
            workspacesService: workspacesServiceInstance
            launcher: overlay.launcher
            controlCenter: overlay.controlCenter
            powerMenu: overlay.powerMenu
            themePicker: overlay.themePicker
            clipboard: overlay.clipboard
            mediaPanel: overlay.mediaPanel
            toolMenu: overlay.toolMenu
            emojiPicker: overlay.emojiPicker
            ensureControlCenter: function () {
                return overlay.controlCenter;
            }
        }
    }
}
