pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import "../../theme" as Palette
import "../../components/material"

// Every workspace at a glance: cards floating over the dimmed desktop, each
// labelled with its number and window count ("current" on the one you're
// on), live window thumbnails inside, special workspaces in their own
// column, and the shortcuts underneath. Drag a window onto another card to
// move it there; 1–9 / 0 jump straight to a workspace.
PanelWindow {
    id: root

    required property var service

    readonly property int selected: service ? service.selected : 0
    readonly property bool active: service ? service.active : false
    readonly property int currentId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
    readonly property var specials: Hyprland.workspaces.values.filter(w => w.id < 0)

    // Cards as wide as fit across the screen (five, plus the special
    // column when there is one), within 150–256 px, in 16:9.
    readonly property real cardW: {
        var across = 5 + (specials.length > 0 ? 1 : 0);
        var gaps = 4 * 14 + (specials.length > 0 ? 2 * 28 + 1 : 0);
        return Math.max(150, Math.min(256, Math.floor((width - 96 - gaps) / across)));
    }
    readonly property real cardH: Math.round(cardW * 9 / 16)

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
        // Nearly opaque theme background, so busy wallpapers and desktop
        // widgets don't compete with the cards.
        color: Palette.Theme.bg
        opacity: root.active ? 0.9 : 0
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
        Keys.onUpPressed: root.service.step(-5)
        Keys.onDownPressed: root.service.step(5)
        Keys.onTabPressed: event => {
            if (event.modifiers & Qt.ShiftModifier)
                root.service.step(-1);
            else
                root.service.step(1);
        }
        Keys.onReturnPressed: root.service.confirm()
        Keys.onEnterPressed: root.service.confirm()
        Keys.onEscapePressed: root.service.cancel()
        // 1–9 and 0 (workspace 10) jump straight there.
        Keys.onPressed: event => {
            if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9) {
                var index = event.key === Qt.Key_0 ? 9 : event.key - Qt.Key_1;
                root.service.selectIndex(index);
                root.service.confirm();
                event.accepted = true;
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 22

        Row {
            spacing: 28

            Grid {
                id: grid
                columns: 5
                columnSpacing: 14
                rowSpacing: 18

                Repeater {
                    model: 10

                    delegate: Column {
                        id: cell
                        required property int index

                        readonly property int workspaceId: index + 1
                        readonly property var ws: root.service.workspaceFor(workspaceId)
                        readonly property int windowCount: ws ? ws.toplevels.values.length : 0
                        readonly property bool focused: index === root.selected

                        spacing: 6

                        CardLabel {
                            width: root.cardW
                            badge: String(cell.workspaceId)
                            text: cell.windowCount === 0 ? "empty" : cell.windowCount + (cell.windowCount === 1 ? " window" : " windows")
                            current: cell.workspaceId === root.currentId
                        }

                        Item {
                            width: root.cardW
                            height: root.cardH

                            WorkspaceCard {
                                anchors.fill: parent
                                ws: cell.ws
                                label: String(cell.workspaceId)
                                focused: cell.focused
                                draggable: true
                                onActivated: {
                                    root.service.selectIndex(cell.index);
                                    root.service.confirm();
                                }
                                onHoverSelected: root.service.selectIndex(cell.index)
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
                        }
                    }
                }
            }

            Rectangle {
                visible: root.specials.length > 0
                width: 1
                height: grid.height
                color: Palette.Theme.accent
                opacity: 0.35
            }

            Column {
                visible: root.specials.length > 0
                spacing: 12

                Text {
                    text: "SPECIAL"
                    color: Palette.Theme.accent
                    font.family: Palette.Theme.fontSans
                    font.pixelSize: Palette.Theme.fontSizeXs
                    font.weight: Font.Bold
                    font.letterSpacing: 2
                }

                Repeater {
                    model: root.specials

                    delegate: Column {
                        id: special
                        required property var modelData
                        readonly property int windowCount: modelData.toplevels.values.length
                        readonly property string title: modelData.name.replace(/^special:/, "")

                        spacing: 6

                        CardLabel {
                            width: root.cardW
                            badge: special.title.charAt(0).toUpperCase()
                            text: special.title + "  ·  " + (special.windowCount === 0 ? "empty" : special.windowCount + (special.windowCount === 1 ? " window" : " windows"))
                        }

                        WorkspaceCard {
                            width: root.cardW
                            height: root.cardH
                            ws: special.modelData
                            label: special.title.charAt(0).toUpperCase()
                            onActivated: {
                                root.service.cancel();
                                Hyprland.dispatch("togglespecialworkspace " + special.title);
                            }
                        }
                    }
                }
            }
        }
    }

    // ── pieces ─────────────────────────────────────────────────────

    // "[3] 1 window ............ current" above a card.
    component CardLabel: Item {
        id: label
        property string badge: ""
        property string text: ""
        property bool current: false

        height: 18

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Rectangle {
                width: Math.max(18, badgeText.implicitWidth + 8)
                height: 18
                radius: 5
                color: label.current ? Palette.Theme.accent : Palette.Theme.surfaceContainerHighest

                Text {
                    id: badgeText
                    anchors.centerIn: parent
                    text: label.badge
                    color: label.current ? Palette.Theme.accentText : Palette.Theme.textPrimary
                    font.family: Palette.Theme.fontSans
                    font.pixelSize: Palette.Theme.fontSizeXs
                    font.weight: Font.Bold
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: label.text
                color: Palette.Theme.textPrimary
                font.family: Palette.Theme.fontSans
                font.pixelSize: Palette.Theme.fontSizeXs
            }
        }

        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: label.current
            text: "current"
            color: Palette.Theme.accent
            font.family: Palette.Theme.fontSans
            font.pixelSize: Palette.Theme.fontSizeXs
            font.weight: Font.DemiBold
        }
    }

    // A workspace's card: its windows as live thumbnails (up to four, then
    // "+N"), or its number faintly when empty. The selected card wears an
    // accent outline.
    component WorkspaceCard: Rectangle {
        id: card
        property var ws: null
        property string label: ""
        property bool focused: false
        property bool draggable: false
        signal activated
        signal hoverSelected

        readonly property bool hasWindows: tiles.count > 0

        radius: Palette.Theme.radiusMedium
        // Opaque, so translucent themes don't show the desktop through it.
        color: Palette.Theme.surfaceSolid
        border.width: focused ? 2 : 1
        border.color: focused ? Palette.Theme.accent : Palette.Theme.outlineVariant
        scale: focused ? 1 : 0.97

        Behavior on scale {
            SpatialMotion {
                fast: true
            }
        }
        Behavior on border.color {
            ColorMotion {}
        }

        layer.enabled: focused
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.45)
            shadowBlur: 0.6
            shadowVerticalOffset: 3
        }

        Text {
            anchors.centerIn: parent
            visible: !card.hasWindows
            text: card.label
            color: Palette.Theme.textMuted
            opacity: 0.7
            font.family: Palette.Theme.fontSans
            font.pixelSize: Palette.Theme.fontSizeHeadline
            font.weight: Font.Bold
        }

        MouseArea {
            anchors.fill: parent
            visible: !card.hasWindows
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: card.activated()
        }

        // Hovering anywhere on the card selects it (accent border), even over
        // the window tiles, whose own mouse areas handle clicks and drags.
        HoverHandler {
            onHoveredChanged: {
                if (hovered)
                    card.hoverSelected();
            }
        }

        // Plain Item (not a positioner) so a dragged tile owns its x/y.
        Item {
            id: area
            anchors.fill: parent
            anchors.margins: 5

            Repeater {
                id: tiles
                model: card.ws ? card.ws.toplevels : null

                delegate: Item {
                    id: tile
                    required property var modelData
                    required property int index

                    readonly property bool overflow: tiles.count > 4 && index === 3
                    readonly property int cols: tiles.count > 1 ? 2 : 1
                    readonly property real tileW: cols > 1 ? (area.width - 4) / 2 : area.width
                    readonly property real tileH: tiles.count > 2 ? (area.height - 4) / 2 : area.height
                    readonly property real restX: (index % cols) * (tileW + 4)
                    readonly property real restY: Math.floor(index / cols) * (tileH + 4)

                    visible: index < 4
                    width: tileW
                    height: tileH
                    x: restX
                    y: restY

                    ClippingRectangle {
                        anchors.fill: parent
                        radius: Palette.Theme.radiusXs
                        color: Palette.Theme.surfaceContainerHighest

                        // Only exists while the overview is open: each
                        // capture holds GPU buffers, and tearing them down
                        // at shell exit has crashed in libwayland.
                        Loader {
                            anchors.fill: parent
                            active: root.active && !tile.overflow
                            sourceComponent: ScreencopyView {
                                captureSource: tile.modelData.wayland
                                live: true
                                paintCursor: false
                            }
                        }

                        // Not parent.radius: a ClippingRectangle's children
                        // live in a content item that has no radius.
                        StateLayer {
                            radius: Palette.Theme.radiusXs
                            hovered: tileMouse.containsMouse && !tileMouse.drag.active
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: tile.overflow
                            text: "+" + (tiles.count - 3)
                            color: Palette.Theme.textMuted
                            font.family: Palette.Theme.fontSans
                            font.pixelSize: Palette.Theme.fontSizeBody
                        }

                        IconImage {
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            anchors.margins: 3
                            implicitSize: 14
                            visible: !tile.overflow && tile.modelData.wayland && tile.modelData.wayland.appId
                            source: tile.modelData.wayland && tile.modelData.wayland.appId ? Quickshell.iconPath(tile.modelData.wayland.appId, true) : ""
                            smooth: true
                        }
                    }

                    Drag.active: tileMouse.drag.active
                    Drag.keys: ["workspace-window"]
                    Drag.hotSpot.x: width / 2
                    Drag.hotSpot.y: height / 2

                    MouseArea {
                        id: tileMouse
                        anchors.fill: parent
                        enabled: !tile.overflow
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        drag.target: card.draggable ? tile : null
                        onPressed: tile.z = 100
                        onReleased: {
                            tile.Drag.drop();
                            tile.z = 0;
                            tile.x = tile.restX;
                            tile.y = tile.restY;
                        }
                        onClicked: card.activated()
                    }
                }
            }
        }
    }
}
