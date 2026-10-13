import Quickshell
import Quickshell.Wayland
import QtQuick
import "../material"
import "../../modules/launcher"
import "../../modules/controlcenter"
import "../../modules/powermenu"
import "../../modules/theme"
import "../../modules/clipboard"
import "../../modules/servicemanager"
import "../../modules/bar"
import "../../modules/calendar"
import "../../modules/toolmenu"
import "../../modules/barlayout"
import "../../modules/wallpicker"
import "../../modules/dock"
import "../../services"
import "../../components/material"
import "../../config/Ui.js" as Ui
import "../../theme" as Palette

PanelWindow {
    id: root

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    exclusiveZone: -1
    color: "transparent"
    mask: Region {
        Region {
            width: root.active ? root.width : 0
            height: root.active ? root.height : 0
            intersection: Intersection.Combine
        }
        Region {
            item: root.dockShown ? bottomStage : null
            intersection: Intersection.Combine
        }
        Region {
            item: root.dockAutoHidden ? dockTrigger : null
            intersection: Intersection.Combine
        }
        Region {
            item: dockPopups.menuVisible ? dockPopups.menuRect : null
            intersection: Intersection.Combine
        }
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-center-overlay"
    WlrLayershell.keyboardFocus: active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property var bar: null
    property var notificationCenter: null
    property var idleService: null
    property var barLayout: null
    property var widgetsService: null
    property var settingsWindow: null
    readonly property bool verticalBar: barLayout ? barLayout.vertical : false
    readonly property bool active: (activeTopPanel !== null) || (activeBottomPanel !== null)

    // Central modules origin edge:
    // Top origin: Control Center, Power Menu, Tool Menu, Media Panel.
    // Bottom origin: Launcher (shaders/sounds live inside it), Theme, Clipboard,
    // Service Manager, Calendar, Bar Layout, Wallpaper Picker.
    function isTopModule(panel) {
        return panel === controlCenterItem
            || panel === powerMenuItem
            || panel === toolMenuItem
            || panel === mediaPanelItem;
    }

    property var currentTargetPanel: null

    // Only the panel that last opened owns its stage. One that was just
    // switched away from stays visible a moment longer while its StageSlot
    // fades it out, but no longer holds the stage open.
    readonly property var activeTopPanel: currentTargetPanel && currentTargetPanel.visible && isTopModule(currentTargetPanel) ? currentTargetPanel : null
    readonly property var activeBottomPanel: currentTargetPanel && currentTargetPanel.visible && !isTopModule(currentTargetPanel) ? currentTargetPanel : null

    // The dock is the bottom stage's resting state: it shows whenever no
    // bottom panel is open, and the slab morphs between it and those panels.
    // It deliberately doesn't count towards `active` (that grabs the whole
    // screen's input and keyboard focus).
    //
    // While the current workspace has windows it auto-hides; hovering the
    // strip at the bottom edge (dockTrigger) reveals it until the pointer
    // has left the dock again. An empty workspace keeps it up permanently.
    property bool dockRevealed: false
    readonly property bool dockCanShow: dockItem.wanted && activeBottomPanel === null
    readonly property bool dockShown: dockCanShow && (!dockItem.workspaceBusy || dockRevealed)
    readonly property bool dockAutoHidden: dockCanShow && !dockShown
    readonly property bool dockPointerInside: dockTrigger.hovered || dockItem.holdOpen

    onDockPointerInsideChanged: {
        if (dockPointerInside) {
            dockHideTimer.stop();
            dockRevealed = true;
        } else {
            dockHideTimer.restart();
        }
    }

    Timer {
        id: dockHideTimer
        interval: 450
        onTriggered: root.dockRevealed = false
    }

    // Thin hover strip along the bottom edge, only part of the input region
    // while the dock is tucked away.
    Item {
        id: dockTrigger

        readonly property bool hovered: triggerHover.hovered

        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.max(360, dockItem.implicitWidth + 120)
        height: 6

        HoverHandler {
            id: triggerHover
        }
    }


    property alias launcher: launcherItem
    property alias controlCenter: controlCenterItem
    property alias powerMenu: powerMenuItem
    property alias themePicker: themePickerItem
    property alias clipboard: clipboardItem
    property alias serviceManager: serviceManagerItem
    property alias mediaPanel: mediaPanelItem
    property alias toolMenu: toolMenuItem
    property alias calendarPicker: calendarPickerItem
    property alias barLayoutPicker: barLayoutPickerItem
    property alias wallpaperPicker: wallpaperPickerItem
    property alias themes: themeService

    // All center-origin panels share this layer surface. Closing every other
    // panel before a new one appears prevents stacked backdrops and focus.
    // They close with their normal delay, not immediately, so their StageSlot
    // can crossfade them into the new panel.
    function presentOnly(panel) {
        currentTargetPanel = panel;
        if (panel !== launcherItem && launcherItem.visible)
            launcherItem.closeLauncher();
        if (panel !== controlCenterItem && controlCenterItem.visible)
            controlCenterItem.closeControlCenter();
        if (panel !== powerMenuItem && powerMenuItem.visible)
            powerMenuItem.closePowerMenu();
        if (panel !== themePickerItem && themePickerItem.visible)
            themePickerItem.close();
        if (panel !== clipboardItem && clipboardItem.visible)
            clipboardItem.close();
        if (panel !== serviceManagerItem && serviceManagerItem.visible)
            serviceManagerItem.close();
        if (panel !== mediaPanelItem && mediaPanelItem.visible)
            mediaPanelItem.close();
        if (panel !== toolMenuItem && toolMenuItem.visible)
            toolMenuItem.closeToolMenu();
        if (panel !== calendarPickerItem && calendarPickerItem.visible)
            calendarPickerItem.close();
        if (panel !== barLayoutPickerItem && barLayoutPickerItem.visible)
            barLayoutPickerItem.close();
        if (panel !== wallpaperPickerItem && wallpaperPickerItem.visible)
            wallpaperPickerItem.close();
    }

    // Closes the panel on screen, not one still fading out from a switch.
    function closeActive() {
        const panel = activeTopPanel || activeBottomPanel;
        if (panel === launcherItem)
            launcherItem.closeLauncher();
        else if (panel === controlCenterItem)
            controlCenterItem.closeControlCenter();
        else if (panel === powerMenuItem)
            powerMenuItem.closePowerMenu();
        else if (panel === themePickerItem)
            themePickerItem.close();
        else if (panel === clipboardItem)
            clipboardItem.close();
        else if (panel === serviceManagerItem)
            serviceManagerItem.close();
        else if (panel === mediaPanelItem)
            mediaPanelItem.close();
        else if (panel === toolMenuItem)
            toolMenuItem.closeToolMenu();
        else if (panel === calendarPickerItem)
            calendarPickerItem.close();
        else if (panel === barLayoutPickerItem)
            barLayoutPickerItem.close();
        else if (panel === wallpaperPickerItem)
            wallpaperPickerItem.close();
    }

    ThemeService {
        id: themeService
    }

    ShaderService {
        id: shaderService
    }

    WayclickService {
        id: wayclickService
    }

    ClipboardService {
        id: clipboardService
    }

    // Invisible click-outside-to-close catcher. Sits below the notch so it
    // never intercepts clicks meant for the panel's own content.
    MouseArea {
        anchors.fill: parent
        visible: root.active
        onClicked: root.closeActive()
    }

    // Seed dimensions: the bar's collapsed notch width and height.
    // When a panel opens the stage grows from these values, creating a
    // seamless expansion from the clock/cava notch rather than a separate
    // overlay appearing on top of it. The vertical bar has no top notch to
    // seed from, so the stage just starts flat (zero height) and grows
    // from whichever edge (top or bottom) the next panel opens from.
    readonly property real barSlabWidth: bar ? (bar.centerCapsuleSlabWidth || 120) : 120
    readonly property bool island: barLayout ? barLayout.island : false
    // In island mode the bar's island is inset like the other bar capsules.
    readonly property real barSlabHeight: root.verticalBar ? 0 : (bar ? bar.height - (root.island ? bar.islandGap : 0) : 34)

    // With the left bar in notch mode the screen has a frame (ScreenFrame.qml,
    // same condition). The stages then grow out of it, Caelestia-style: in
    // the frame's color, from its inner edge, joined by curves at its radius.
    readonly property bool framed: barLayout ? (barLayout.loaded && barLayout.vertical && !root.island) : false
    property real frameInset: framed ? Ui.screenFrameBorder : 0
    Behavior on frameInset {
        EffectMotion {}
    }
    readonly property color stageColor: framed ? Palette.Theme.bg : Palette.Theme.surfaceContainer
    readonly property real stageTint: framed ? 0 : Palette.Theme.surfaceTintOpacity
    readonly property real stageWing: framed ? Ui.screenFrameRadius : 9

    // ── TOP STAGE (Control Center, Power Menu, Tool Menu, Media Panel) ───
    Notch {
        id: topStage
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: root.frameInset
        bottomAligned: false
        island: root.island
        islandGap: bar ? bar.islandGap : 4
        wingSize: root.stageWing
        slabRadius: 20
        color: root.stageColor
        tintOpacity: root.stageTint

        Behavior on color {
            ColorMotion {}
        }

        readonly property var panel: root.activeTopPanel

        slabWidth: panel ? panel.implicitWidth : root.barSlabWidth
        slabHeight: panel ? panel.implicitHeight : root.barSlabHeight
        opacity: panel ? 1 : 0

        // barSlabHeight/barSlabWidth are seeded from barLayout.vertical, which
        // briefly holds its declared default before the persisted bar-layout
        // file finishes loading on shell startup/reload. Without this guard,
        // that transient flip plays the OutBack overshoot below — visible as
        // the idle notch "wobbling" as the bar's real edge resolves.
        Behavior on slabWidth {
            enabled: !root.barLayout || root.barLayout.loaded
            SpatialMotion {}
        }
        Behavior on slabHeight {
            enabled: !root.barLayout || root.barLayout.loaded
            SpatialMotion {}
        }
        Behavior on opacity {
            EffectMotion {}
        }

        ControlCenter {
            id: controlCenterItem
            maxWidth: root.width
            maxHeight: root.height
            notificationCenter: root.notificationCenter
            bar: root.bar
            idleService: root.idleService
        }

        PowerMenu {
            id: powerMenuItem
            maxWidth: root.width
            launcher: launcherItem
            controlCenter: controlCenterItem
        }

        ToolMenu {
            id: toolMenuItem
            maxWidth: root.width
            launcher: launcherItem
            controlCenter: controlCenterItem
        }

        MediaPanel {
            id: mediaPanelItem
        }
    }

    // ── BOTTOM STAGE (Launcher, Wallpapers, Themes, Clipboard, etc.) ──
    Notch {
        id: bottomStage
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.frameInset
        bottomAligned: true
        island: root.island
        islandGap: 8
        wingSize: root.stageWing
        slabRadius: 20
        color: root.stageColor
        tintOpacity: root.stageTint

        Behavior on color {
            ColorMotion {}
        }

        readonly property var panel: root.activeBottomPanel ? root.activeBottomPanel : (root.dockShown ? dockItem : null)

        slabWidth: panel ? panel.implicitWidth : 120
        slabHeight: panel ? panel.implicitHeight : 0
        opacity: panel ? 1 : 0

        Behavior on slabWidth {
            SpatialMotion {}
        }
        Behavior on slabHeight {
            SpatialMotion {}
        }
        Behavior on opacity {
            EffectMotion {}
        }

        Dock {
            id: dockItem
            // Stays up while its slot fades it out under the next panel.
            visible: bottomStage.panel === dockItem || dockSlot.reveal > 0
            maxWidth: root.width
            widgetsService: root.widgetsService
        }

        Launcher {
            id: launcherItem
            maxWidth: root.width
            controlCenter: controlCenterItem
            serviceManager: serviceManagerItem
            shaderService: shaderService
            wayclickService: wayclickService
            widgetsService: root.widgetsService
            settingsWindow: root.settingsWindow
        }

        ThemePicker {
            id: themePickerItem
            maxWidth: root.width
            maxHeight: root.height
            service: themeService
            launcher: launcherItem
            controlCenter: controlCenterItem
            powerMenu: powerMenuItem
        }

        Clipboard {
            id: clipboardItem
            maxWidth: root.width
            maxHeight: root.height
            service: clipboardService
        }

        ServiceManager {
            id: serviceManagerItem
            maxWidth: root.width
            maxHeight: root.height
        }

        CalendarPanel {
            id: calendarPickerItem
            maxWidth: root.width
            maxHeight: root.height
        }

        BarLayoutPicker {
            id: barLayoutPickerItem
            service: root.barLayout
            launcher: launcherItem
            controlCenter: controlCenterItem
            powerMenu: powerMenuItem
        }

        WallpaperPicker {
            id: wallpaperPickerItem
            maxWidth: root.width
            maxHeight: root.height
            launcher: launcherItem
            controlCenter: controlCenterItem
            powerMenu: powerMenuItem
            themeService: themeService
        }
    }

    // Size, position and switch motion for every panel (see StageSlot.qml).
    StageSlot { panel: controlCenterItem; stage: topStage }
    StageSlot { panel: powerMenuItem; stage: topStage }
    StageSlot { panel: toolMenuItem; stage: topStage }
    StageSlot { panel: mediaPanelItem; stage: topStage }
    StageSlot { id: dockSlot; panel: dockItem; stage: bottomStage; fromBottom: true }
    StageSlot { panel: launcherItem; stage: bottomStage; fromBottom: true }
    StageSlot { panel: themePickerItem; stage: bottomStage; fromBottom: true }
    StageSlot { panel: clipboardItem; stage: bottomStage; fromBottom: true }
    StageSlot { panel: serviceManagerItem; stage: bottomStage; fromBottom: true }
    StageSlot { panel: calendarPickerItem; stage: bottomStage; fromBottom: true }
    StageSlot { panel: barLayoutPickerItem; stage: bottomStage; fromBottom: true }
    StageSlot { panel: wallpaperPickerItem; stage: bottomStage; fromBottom: true }

    DockPopups {
        id: dockPopups
        dock: dockItem
    }

    Connections {
        target: launcherItem
        function onAboutToOpen() { root.presentOnly(launcherItem); }
    }
    Connections {
        target: controlCenterItem
        function onAboutToOpen() { root.presentOnly(controlCenterItem); }
    }
    Connections {
        target: powerMenuItem
        function onAboutToOpen() { root.presentOnly(powerMenuItem); }
    }
    Connections {
        target: themePickerItem
        function onAboutToOpen() { root.presentOnly(themePickerItem); }
    }
    Connections {
        target: clipboardItem
        function onAboutToOpen() { root.presentOnly(clipboardItem); }
    }
    Connections {
        target: serviceManagerItem
        function onAboutToOpen() { root.presentOnly(serviceManagerItem); }
    }
    Connections {
        target: mediaPanelItem
        function onAboutToOpen() { root.presentOnly(mediaPanelItem); }
    }
    Connections {
        target: toolMenuItem
        function onAboutToOpen() { root.presentOnly(toolMenuItem); }
    }
    Connections {
        target: calendarPickerItem
        function onAboutToOpen() { root.presentOnly(calendarPickerItem); }
    }
    Connections {
        target: barLayoutPickerItem
        function onAboutToOpen() { root.presentOnly(barLayoutPickerItem); }
    }
    Connections {
        target: wallpaperPickerItem
        function onAboutToOpen() { root.presentOnly(wallpaperPickerItem); }
    }
}
