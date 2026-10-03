pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import "../../theme" as Palette
import "../../components/material"

PanelWindow {
    id: root

    required property var service

    readonly property int selected: service ? service.selected : 0
    readonly property bool active: service ? service.active : false

    visible: active

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell:workspaces"
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    color: "transparent"

    IpcHandler {
        target: "workspaces"
        function next(): void {
            root.service.step(1);
        }
        function prev(): void {
            root.service.step(-1);
        }
        function activate(): void {
            root.service.confirm();
        }
        function cancel(): void {
            root.service.cancel();
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        onClicked: root.service.cancel()
    }

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: root.active ? 0.35 : 0
        Behavior on opacity {
            EffectMotion {}
        }
    }

    Item {
        id: keyHandler
        anchors.fill: parent
        focus: root.active

        Keys.onLeftPressed: root.service.step(-1)
        Keys.onRightPressed: root.service.step(1)
        Keys.onTabPressed: event => {
            if (event.modifiers & Qt.ShiftModifier)
                root.service.step(-1);
            else
                root.service.step(1);
        }
        Keys.onReturnPressed: root.service.confirm()
        Keys.onEnterPressed: root.service.confirm()
        Keys.onEscapePressed: root.service.cancel()
    }

    // Fixed 5×2 grid — one cell per Hyprland workspace (1-10, matching the
    // SUPER+1..0 keybinds). Windows in a workspace render as live thumbnails
    // inside its cell and can be dragged onto another cell to move them
    // there without switching to it.
    Rectangle {
        id: panel
        anchors.centerIn: parent

        readonly property int columns: 5
        readonly property int rows: 2
        readonly property int cellSpacing: 5
        readonly property int cellW: 210
        readonly property int cellH: 120
        readonly property int pad: 10

        width: columns * cellW + (columns - 1) * cellSpacing + pad * 2
        height: rows * cellH + (rows - 1) * cellSpacing + pad * 2

        radius: Palette.Theme.radiusLarge
        color: Palette.Theme.surfaceContainer

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            onClicked: {}
        }

        Grid {
            anchors.fill: parent
            anchors.margins: panel.pad
            columns: panel.columns
            spacing: panel.cellSpacing

            Repeater {
                model: 10

                delegate: Item {
                    id: cell
                    required property int index

                    readonly property int workspaceId: index + 1
                    readonly property var ws: root.service.workspaceFor(workspaceId)
                    readonly property bool focused: index === root.selected
                    readonly property bool hasWindows: winRepeater.count > 0

                    width: panel.cellW
                    height: panel.cellH
                    z: focused ? 1 : 0
                    scale: focused ? 1.0 : 0.97
                    opacity: focused ? 1.0 : 0.85

                    Behavior on scale {
                        SpatialMotion {
                            fast: true
                        }
                    }
                    Behavior on opacity {
                        EffectMotion {}
                    }

                    Rectangle {
                        id: card
                        anchors.fill: parent
                        radius: Palette.Theme.radiusSmall
                        color: cell.hasWindows ? Palette.Theme.surfaceContainerHigh : Palette.Theme.surfaceContainerLow

                        // Soft tint + ring instead of a flat saturated stroke —
                        // reads as "selected" without clashing against live
                        // thumbnail content behind it.
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            visible: cell.focused
                            color: Palette.Theme.accent
                            opacity: 0.10
                        }

                        border.width: cell.focused ? 1.5 : 0
                        border.color: Palette.Theme.accent

                        layer.enabled: cell.focused
                        layer.effect: MultiEffect {
                            shadowEnabled: true
                            shadowColor: Qt.rgba(0, 0, 0, 0.45)
                            shadowBlur: 0.6
                            shadowVerticalOffset: 3
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: !cell.hasWindows
                            text: cell.workspaceId
                            color: Palette.Theme.textMuted
                            opacity: 0.4
                            font.family: Palette.Theme.fontMono
                            font.pixelSize: Palette.Theme.fontSizeHeadline
                        }

                        // up to 4 windows tiled in a mini 2×2; a 5th+ just
                        // shows a "+N" badge instead of shrinking further.
                        // Plain Item (not a Grid/positioner) so a dragged
                        // tile owns its x/y instead of fighting a layout
                        // that would otherwise snap it straight back.
                        Item {
                            id: winArea
                            anchors.fill: parent
                            anchors.margins: 4

                            Repeater {
                                id: winRepeater
                                model: cell.ws ? cell.ws.toplevels : null

                                delegate: Item {
                                    id: winTile
                                    required property var modelData
                                    required property int index

                                    readonly property bool overflow: winRepeater.count > 4 && winTile.index === 3
                                    readonly property int cols: winRepeater.count > 1 ? 2 : 1
                                    readonly property real tileW: cols > 1 ? (winArea.width - 3) / 2 : winArea.width
                                    readonly property real tileH: winRepeater.count > 2 ? (winArea.height - 3) / 2 : winArea.height
                                    readonly property real restX: (winTile.index % cols) * (tileW + 3)
                                    readonly property real restY: Math.floor(winTile.index / cols) * (tileH + 3)

                                    readonly property bool hovered: winDrag.containsMouse && !winDrag.drag.active

                                    visible: winTile.index < 4
                                    width: tileW
                                    height: tileH
                                    x: restX
                                    y: restY
                                    scale: winTile.hovered ? 1.04 : 1.0

                                    Behavior on scale {
                                        SpatialMotion {
                                            fast: true
                                        }
                                    }

                                    Rectangle {
                                        id: winCard
                                        anchors.fill: parent
                                        radius: 6
                                        color: Palette.Theme.surfaceContainerHighest
                                        clip: true

                                        ScreencopyView {
                                            anchors.fill: parent
                                            visible: !winTile.overflow
                                            captureSource: winTile.modelData.wayland
                                            live: root.active
                                            paintCursor: false
                                        }

                                        // hover "glimpse" — a brief soft
                                        // white wash, no border/outline
                                        Rectangle {
                                            anchors.fill: parent
                                            visible: !winTile.overflow
                                            color: Palette.Theme.textPrimary
                                            opacity: winTile.hovered ? Palette.Theme.stateHover : 0

                                            Behavior on opacity {
                                                EffectMotion {}
                                            }
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            visible: winTile.overflow
                                            color: Palette.Theme.surfaceContainerHighest

                                            Text {
                                                anchors.centerIn: parent
                                                text: "+" + (winRepeater.count - 3)
                                                color: Palette.Theme.textMuted
                                                font.family: Palette.Theme.fontMono
                                                font.pixelSize: Palette.Theme.fontSizeBody
                                            }
                                        }

                                        IconImage {
                                            anchors.left: parent.left
                                            anchors.bottom: parent.bottom
                                            anchors.margins: 3
                                            implicitSize: 14
                                            visible: !winTile.overflow && winTile.modelData.wayland && winTile.modelData.wayland.appId
                                            source: winTile.modelData.wayland && winTile.modelData.wayland.appId ? Quickshell.iconPath(winTile.modelData.wayland.appId, true) : ""
                                            smooth: true
                                        }
                                    }

                                    Drag.active: winDrag.drag.active
                                    Drag.keys: ["workspace-window"]
                                    Drag.hotSpot.x: width / 2
                                    Drag.hotSpot.y: height / 2

                                    MouseArea {
                                        id: winDrag
                                        anchors.fill: parent
                                        enabled: !winTile.overflow
                                        acceptedButtons: Qt.LeftButton
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        drag.target: winTile
                                        onPressed: winTile.z = 100
                                        onReleased: {
                                            winTile.Drag.drop();
                                            winTile.z = 0;
                                            winTile.x = winTile.restX;
                                            winTile.y = winTile.restY;
                                        }
                                        onClicked: {
                                            root.service.selectIndex(cell.index);
                                            root.service.confirm();
                                        }
                                    }
                                }
                            }
                        }
                    }

                    DropArea {
                        anchors.fill: parent
                        keys: ["workspace-window"]
                        onEntered: root.service.selectIndex(cell.index)
                        onDropped: drop => {
                            if (drop.source && drop.source.modelData)
                                root.service.moveWindowToWorkspace(drop.source.modelData.address, cell.workspaceId);
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        visible: !cell.hasWindows
                        acceptedButtons: Qt.LeftButton
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.service.selectIndex(cell.index)
                        onClicked: {
                            root.service.selectIndex(cell.index);
                            root.service.confirm();
                        }
                    }
                }
            }
        }
    }
}
