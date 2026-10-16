pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../theme" as Palette
import "../../components/material"

// Theme picker in the style of Caelestia's scheme list, laid out like the
// launcher: a pill search field on the bottom edge, themes stacked above it.
// Each row previews the theme with a split disc (its background and accent)
// beside its name and kind, and rings the active one. Filtering animates
// through a ScriptModel and the panel resizes to fit.
Item {
    id: root
    visible: false
    // Still visible while the close delay runs, but on its way out.
    readonly property bool closing: closeTimer.running
    focus: visible

    required property var service
    property real maxWidth: 4000
    property real maxHeight: 4000
    property var launcher: null
    property var controlCenter: null
    property var powerMenu: null
    property string query: ""
    property int selected: 0

    readonly property int itemH: 56
    readonly property int maxVisible: 5

    // Prefix matches first, then substring matches, each alphabetical.
    readonly property var themes: {
        if (!service)
            return [];
        var q = query.trim().toLowerCase();
        if (q === "")
            return service.themes;
        return service.themes.filter(n => n.toLowerCase().indexOf(q) !== -1).sort((a, b) => (b.toLowerCase().startsWith(q) ? 1 : 0) - (a.toLowerCase().startsWith(q) ? 1 : 0) || a.localeCompare(b));
    }

    readonly property int visibleRows: Math.max(1, Math.min(maxVisible, themes.length))
    // Same footprint as the launcher (row height, rows, width).
    implicitWidth: Math.min(maxWidth - 32, Palette.Theme.listPanelWidth)
    implicitHeight: searchRow.height + visibleRows * itemH + 6

    signal aboutToOpen
    signal aboutToClose

    IpcHandler {
        target: "theme"
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
        service.refresh();
        // Start on the active theme.
        selected = Math.max(0, themes.indexOf(service.activeTheme));
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
        if (index < 0 || index >= themes.length)
            return;
        service.apply(themes[index]);
        close();
    }

    function move(delta) {
        if (themes.length === 0)
            return;
        selected = Math.max(0, Math.min(themes.length - 1, selected + delta));
    }

    function paletteFor(name) {
        return service && service.palettes ? service.palettes[name] : undefined;
    }

    function prettyName(name) {
        return name.charAt(0).toUpperCase() + name.slice(1).replace(/-/g, " ");
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

        // ── themes ────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 6
            clip: true

            Text {
                anchors.centerIn: parent
                visible: root.themes.length === 0
                text: "No themes match '" + root.query + "'"
                color: Palette.Theme.textMuted
                font.family: Palette.Theme.fontSans
                font.pixelSize: Palette.Theme.fontSizeSmall
            }

            ListView {
                id: list
                anchors.fill: parent
                verticalLayoutDirection: ListView.BottomToTop
                model: ScriptModel {
                    values: root.themes
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
                interactive: root.themes.length > root.maxVisible
                boundsBehavior: Flickable.StopAtBounds

                onCurrentIndexChanged: if (currentIndex >= 0)
                    positionViewAtIndex(currentIndex, ListView.Contain)
                // Keep the selection in view while the panel springs to
                // its new height and as the list changes.
                onHeightChanged: keepInView()
                onCountChanged: keepInView()
                function keepInView() {
                    if (count === 0)
                        return;
                    if (currentIndex <= 0)
                        positionViewAtBeginning();
                    else
                        positionViewAtIndex(currentIndex, ListView.Contain);
                }

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

                    required property string modelData
                    required property int index

                    readonly property var pal: root.paletteFor(modelData)
                    readonly property bool active: modelData === root.service.activeTheme
                    readonly property color base: pal && pal.bg ? pal.bg : Palette.Theme.surfaceContainerHighest
                    readonly property color accent: pal && pal.accent ? pal.accent : Palette.Theme.accent

                    width: ListView.view.width
                    height: root.itemH

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: 14

                        // Split disc: the theme's background on the left,
                        // its accent on the right, ringed in its accent when
                        // it's the active theme.
                        Item {
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            Layout.alignment: Qt.AlignVCenter

                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: "transparent"
                                border.width: row.active ? 2 : 0
                                border.color: row.accent
                            }

                            Item {
                                anchors.fill: parent
                                anchors.margins: row.active ? 3 : 0

                                Rectangle {
                                    anchors.fill: parent
                                    radius: width / 2
                                    color: row.base
                                }

                                Item {
                                    x: parent.width / 2
                                    width: parent.width / 2
                                    height: parent.height
                                    clip: true

                                    Rectangle {
                                        x: -parent.width
                                        width: parent.width * 2
                                        height: parent.height
                                        radius: width / 2
                                        color: row.accent
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 0

                            Text {
                                Layout.fillWidth: true
                                text: row.modelData
                                color: row.active ? Palette.Theme.accent : Palette.Theme.textPrimary
                                font.family: Palette.Theme.fontSans
                                font.pixelSize: Palette.Theme.fontSizeBody
                                font.weight: row.active ? Font.DemiBold : Font.Medium
                                elide: Text.ElideRight
                            }

                            Text {
                                Layout.fillWidth: true
                                text: row.active ? "active" : (row.modelData === "dynamic" ? "from wallpaper" : (row.modelData === "transparent" ? "translucent" : "static"))
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
                    text: "palette"
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
                        text: "Search themes"
                        color: Palette.Theme.textMuted
                        font: parent.font
                    }
                }

                Text {
                    text: root.service ? root.service.activeTheme : ""
                    color: Palette.Theme.textMuted
                    font.family: Palette.Theme.fontMono
                    font.pixelSize: Palette.Theme.fontSizeXs
                    Layout.alignment: Qt.AlignVCenter
                    Layout.rightMargin: 8
                }
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
