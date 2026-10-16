pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../theme" as Palette
import "../../components/material"

// Picks the bar style (spread along the top, compact in the top centre, or
// a vertical bar on the left), built like the theme picker: a search field
// on the bottom edge, styles stacked above it with the same sliding
// highlight and list transitions. Each row previews its layout as a tiny
// screen with the bar drawn in, ringed in accent when it's the active one.
Item {
    id: root

    visible: false
    // Still visible while the close delay runs, but on its way out.
    readonly property bool closing: closeTimer.running
    focus: visible

    required property var service
    property real maxWidth: 4000
    property var launcher: null
    property var controlCenter: null
    property var powerMenu: null
    property string query: ""
    property int selected: 0

    readonly property var allOptions: [
        {
            value: "top",
            label: "Top",
            desc: "Horizontal strip along the top edge"
        },
        {
            value: "compact",
            label: "Compact",
            desc: "Everything gathered in the top centre"
        },
        {
            value: "left",
            label: "Left",
            desc: "Vertical bar along the left edge"
        }
    ]

    // Prefix matches first, then substring matches (name or description).
    readonly property var options: {
        var q = query.trim().toLowerCase();
        if (q === "")
            return allOptions;
        return allOptions.filter(o => o.label.toLowerCase().indexOf(q) !== -1 || o.desc.toLowerCase().indexOf(q) !== -1).sort((a, b) => (b.label.toLowerCase().startsWith(q) ? 1 : 0) - (a.label.toLowerCase().startsWith(q) ? 1 : 0));
    }

    readonly property int itemH: 56
    readonly property int visibleRows: Math.max(1, options.length)
    // Same footprint as the theme picker and launcher.
    implicitWidth: Math.min(maxWidth - 32, Palette.Theme.listPanelWidth)
    implicitHeight: searchRow.height + visibleRows * itemH + 6

    signal aboutToOpen
    signal aboutToClose

    IpcHandler {
        target: "barlayout"
        function toggle(): void {
            root.visible && !root.closing ? root.close() : root.open();
        }
        function open(): void {
            root.open();
        }
        function close(): void {
            root.close();
        }
    }

    function open() {
        if (launcher && launcher.visible)
            launcher.closeLauncher();
        if (controlCenter && controlCenter.visible)
            controlCenter.closeControlCenter();
        if (powerMenu && powerMenu.visible)
            powerMenu.closePowerMenu();
        closeTimer.stop();
        aboutToOpen();
        // Visible first, so the list's fade-ins actually run.
        visible = true;
        search.text = "";
        query = "";
        // Start on the active style.
        selected = Math.max(0, options.findIndex(o => service && o.value === service.style));
        search.forceActiveFocus();
    }

    function close(immediate) {
        if (!visible)
            return;
        if (!closing)
            aboutToClose();
        if (immediate) {
            closeTimer.stop();
            visible = false;
            return;
        }
        if (!closing)
            closeTimer.start();
    }

    function apply(index) {
        if (index < 0 || index >= options.length)
            return;
        service.setStyle(options[index].value);
        close();
    }

    function move(delta) {
        if (options.length === 0)
            return;
        selected = Math.max(0, Math.min(options.length - 1, selected + delta));
    }

    // The list runs bottom-to-top, so Up steps further up the list.
    function handleKey(event) {
        if (event.key === Qt.Key_Escape) {
            if (search.text !== "")
                search.text = "";
            else
                close();
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            move(1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Down) {
            move(-1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            apply(selected);
            event.accepted = true;
        }
    }

    // Hover only selects on real pointer movement (see Launcher.qml).
    property point lastPointer: Qt.point(-1, -1)
    function hoverSelect(item, mouse, index) {
        var p = item.mapToItem(null, mouse.x, mouse.y);
        if (p.x === lastPointer.x && p.y === lastPointer.y)
            return;
        lastPointer = p;
        selected = index;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── styles ────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 6
            clip: true

            Text {
                anchors.centerIn: parent
                visible: root.options.length === 0
                text: "No bar styles match '" + root.query + "'"
                color: Palette.Theme.textMuted
                font.family: Palette.Theme.fontSans
                font.pixelSize: Palette.Theme.fontSizeSmall
            }

            ListView {
                id: list
                anchors.fill: parent
                verticalLayoutDirection: ListView.BottomToTop
                model: ScriptModel {
                    values: root.options
                    objectProp: "value"
                }
                currentIndex: root.selected
                highlightFollowsCurrentItem: false
                highlight: MovingHighlight {
                    target: list.currentItem
                    insetX: 6
                    insetY: 2
                    radius: Palette.Theme.radiusMedium
                    color: Palette.Theme.accentTonal
                }
                interactive: false
                boundsBehavior: Flickable.StopAtBounds

                add: Transition {
                    EffectMotion {
                        property: "opacity"
                        alwaysRunToEnd: true
                        from: 0
                        to: 1
                        fast: false
                    }
                }
                remove: Transition {
                    EffectMotion {
                        property: "opacity"
                        alwaysRunToEnd: true
                        to: 0
                    }
                }
                displaced: Transition {
                    SpatialMotion {
                        property: "y"
                    }
                    EffectMotion {
                        property: "opacity"
                        alwaysRunToEnd: true
                        to: 1
                    }
                }

                delegate: Item {
                    id: row

                    required property var modelData
                    required property int index

                    readonly property bool active: root.service && modelData.value === root.service.style

                    width: ListView.view.width
                    height: root.itemH

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 14

                        LayoutPreview {
                            Layout.alignment: Qt.AlignVCenter
                            style: row.modelData.value
                            active: row.active
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: row.modelData.label
                                color: row.active ? Palette.Theme.accent : Palette.Theme.textPrimary
                                font.family: Palette.Theme.fontSans
                                font.pixelSize: Palette.Theme.fontSizeBody
                                font.weight: row.active ? Font.DemiBold : Font.Medium
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: row.active ? "active" : row.modelData.desc
                                color: Palette.Theme.textMuted
                                font.family: Palette.Theme.fontSans
                                font.pixelSize: Palette.Theme.fontSizeXs
                                elide: Text.ElideRight
                            }
                        }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: mouse => root.hoverSelect(rowMouse, mouse, row.index)
                        onClicked: root.apply(row.index)
                    }
                }
            }
        }

        // ── search bar ────────────────────────────────────────────
        Item {
            id: searchRow
            Layout.fillWidth: true
            Layout.preferredHeight: 58

            Rectangle {
                id: searchField
                anchors.fill: parent
                // One even gap on the sides and bottom.
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                anchors.topMargin: 6
                anchors.bottomMargin: 6
                radius: Palette.Theme.radiusMedium
                color: Palette.Theme.surfaceContainerHigh
            }

            RowLayout {
                anchors.fill: searchField
                anchors.leftMargin: 10
                anchors.rightMargin: 8
                spacing: 12

                Text {
                    text: "view_quilt"
                    color: Palette.Theme.accent
                    font.family: Palette.Theme.fontIcons
                    font.weight: Palette.Theme.iconWeight
                    font.pixelSize: Palette.Theme.iconSize
                    Layout.alignment: Qt.AlignVCenter
                }

                TextInput {
                    id: search
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    color: Palette.Theme.textPrimary
                    selectionColor: Palette.Theme.accent
                    selectedTextColor: Palette.Theme.accentText
                    font.family: Palette.Theme.fontSans
                    font.pixelSize: Palette.Theme.fontSizeBody
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    cursorVisible: text !== ""
                    onTextChanged: {
                        root.query = text;
                        root.selected = 0;
                    }
                    Keys.onPressed: event => root.handleKey(event)

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: !parent.text
                        text: "Search bar styles"
                        color: Palette.Theme.textMuted
                        font: parent.font
                    }
                }

                Text {
                    text: root.service ? root.service.style : ""
                    color: Palette.Theme.textMuted
                    font.family: Palette.Theme.fontMono
                    font.pixelSize: Palette.Theme.fontSizeXs
                    Layout.alignment: Qt.AlignVCenter
                    Layout.rightMargin: 8
                }
            }
        }
    }

    // A tiny screen with the bar drawn where this style puts it, ringed in
    // accent when it's the active style (like the theme picker's disc).
    component LayoutPreview: Item {
        id: preview

        property string style: "top"
        property bool active: false

        implicitWidth: 40
        implicitHeight: 30

        Rectangle {
            anchors.fill: parent
            radius: Palette.Theme.radiusXs + 2
            color: "transparent"
            border.width: preview.active ? 2 : 0
            border.color: Palette.Theme.accent
        }

        Rectangle {
            id: screen
            anchors.fill: parent
            anchors.margins: preview.active ? 3 : 0
            radius: Palette.Theme.radiusXs
            color: Palette.Theme.surfaceContainerHighest

            Behavior on anchors.margins {
                SpatialMotion {
                    fast: true
                }
            }

            Rectangle {
                color: Palette.Theme.accent
                radius: 1.5
                x: preview.style === "left" ? 3 : (preview.style === "compact" ? parent.width * 0.3 : 3)
                y: 3
                width: preview.style === "left" ? 4 : (preview.style === "compact" ? parent.width * 0.4 : parent.width - 6)
                height: preview.style === "left" ? parent.height - 6 : 4
            }
        }
    }

    Timer {
        id: closeTimer
        interval: 180
        onTriggered: root.visible = false
    }
    Keys.onPressed: event => root.handleKey(event)
}
