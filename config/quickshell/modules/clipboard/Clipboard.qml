pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../components/material"
import "../../theme" as Palette

// Clipboard history, laid out like the launcher: a pill search field on the
// bottom edge with entries stacked above it, newest nearest the field. A
// ScriptModel animates filtering, images show a thumbnail, links and colors
// get their own icon, and single entries can be deleted. Pinned entries
// (pin button or Ctrl+P) sit first and never age out (ClipboardService).
Item {
    id: root
    visible: false
    // Still visible while the close delay runs, but on its way out.
    readonly property bool closing: closeTimer.running
    focus: visible

    required property var service
    property real maxWidth: 4000
    property real maxHeight: 4000
    property string query: ""
    property int selected: 0

    readonly property int itemH: 56
    // Five rows in view, like the launcher; the rest scroll.
    readonly property int maxVisible: 5

    // Pinned items first (newest pin first), then history newest first,
    // without the history copies of anything pinned.
    readonly property var allEntries: {
        if (!service)
            return [];
        var pinned = service.pins.map(p => ({
                    id: "pin:" + p.pid,
                    pid: p.pid,
                    text: p.text,
                    pinned: true
                }));
        var texts = {};
        pinned.forEach(p => texts[p.text] = true);
        return pinned.concat(service.entries.filter(e => !texts[e.text]));
    }

    // While searching, matches that start with the query (or a word of it)
    // come before ones that merely contain it.
    readonly property var entries: {
        var q = query.trim().toLowerCase();
        if (q === "")
            return allEntries;
        var hits = [];
        allEntries.forEach((e, i) => {
            var t = e.text.toLowerCase();
            var at = t.indexOf(q);
            if (at === -1)
                return;
            var boost = at === 0 ? 2 : (/[\s\-_.\/:]/.test(t[at - 1]) ? 1 : 0);
            hits.push({ e: e, rank: boost * 1000 - i });
        });
        hits.sort((a, b) => b.rank - a.rank);
        return hits.map(h => h.e);
    }

    readonly property int visibleRows: Math.max(1, Math.min(maxVisible, entries.length))
    implicitWidth: Math.min(maxWidth - 32, Palette.Theme.listPanelWidth)
    implicitHeight: searchRow.height + visibleRows * itemH + 6

    signal aboutToOpen
    signal aboutToClose

    IpcHandler {
        target: "clipboard"
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
        search.text = "";
        query = "";
        selected = 0;
        closeTimer.stop();
        aboutToOpen();
        visible = true;
        service.refresh();
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
    function copy(index) {
        if (index >= 0 && index < entries.length) {
            var e = entries[index];
            e.pinned ? service.copyPin(e.pid) : service.copy(e.id);
            close();
        }
    }
    function remove(index) {
        if (index >= 0 && index < entries.length) {
            var e = entries[index];
            e.pinned ? service.unpin(e.pid) : service.remove(e.id);
            selected = Math.max(0, Math.min(selected, entries.length - 2));
        }
    }
    // Pinning moves the item to the front; unpinning leaves its history
    // copy (if cliphist still has it) in place.
    function togglePin(index) {
        if (index >= 0 && index < entries.length) {
            var e = entries[index];
            e.pinned ? service.unpin(e.pid) : service.pin(e);
        }
    }
    function move(delta) {
        if (entries.length)
            selected = Math.max(0, Math.min(entries.length - 1, selected + delta));
    }

    // ── entry kinds ───────────────────────────────────────────────
    function isBinary(entry) {
        return /^\[\[\s*binary data/i.test(entry.text);
    }
    function isImage(entry) {
        return /^\[\[\s*binary data.*(png|jpe?g|webp|gif|bmp)/i.test(entry.text);
    }
    function isLink(entry) {
        return /^\s*(https?:\/\/|www\.)\S+\s*$/i.test(entry.text);
    }
    function colorOf(entry) {
        var m = entry.text.trim().match(/^#([0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$/i);
        return m ? m[0] : "";
    }
    function kindIcon(entry) {
        if (isImage(entry))
            return "image";
        if (isBinary(entry))
            return "draft";
        if (isLink(entry))
            return "link";
        if (colorOf(entry) !== "")
            return "palette";
        return /\n/.test(entry.text) ? "notes" : "content_paste";
    }
    // "[[ binary data 12 KiB png 800x600 ]]" -> "PNG image · 800×600 · 12 KiB"
    function describe(entry) {
        var m = entry.text.match(/binary data\s+([\d.]+\s*\w+)\s+(\w+)(?:\s+(\d+x\d+))?/i);
        if (!m)
            return "Binary data";
        return [m[2].toUpperCase() + " image", m[3] ? m[3].replace("x", "×") : "", m[1]].filter(x => x).join("  ·  ");
    }

    function escapeHtml(s) {
        return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }
    // One line of the entry with the search match picked out.
    function highlight(text) {
        var flat = text.replace(/\s+/g, " ").trim();
        var q = query.trim();
        var at = q === "" ? -1 : flat.toLowerCase().indexOf(q.toLowerCase());
        if (at === -1)
            return escapeHtml(flat);
        // Keep the match in view when it sits deep in a long entry.
        var start = at > 40 ? at - 20 : 0;
        var accent = String(Palette.Theme.accent);
        return (start > 0 ? "…" : "") + escapeHtml(flat.slice(start, at)) + "<font color=\"" + accent + "\"><b>" + escapeHtml(flat.slice(at, at + q.length)) + "</b></font>" + escapeHtml(flat.slice(at + q.length));
    }

    // The list runs bottom-to-top, so Up steps to older entries.
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
        } else if (event.key === Qt.Key_Delete) {
            remove(selected);
            event.accepted = true;
        } else if (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier)) {
            togglePin(selected);
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            copy(selected);
            event.accepted = true;
        }
    }

    // Hover only selects on real pointer movement, not rows sliding under
    // a resting cursor while filtering (see Launcher.qml).
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

        // ── entries ───────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 6
            clip: true

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 6
                visible: root.entries.length === 0

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.query === "" ? "content_paste_off" : "search_off"
                    color: Palette.Theme.textMuted
                    font.family: Palette.Theme.fontIcons
                    font.weight: Palette.Theme.iconWeight
                    font.pixelSize: Palette.Theme.iconSizeLarge
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.query === "" ? "Clipboard history is empty" : "No results for '" + root.query + "'"
                    color: Palette.Theme.textMuted
                    font.family: Palette.Theme.fontSans
                    font.pixelSize: Palette.Theme.fontSizeSmall
                }
            }

            ListView {
                id: list
                anchors.fill: parent
                verticalLayoutDirection: ListView.BottomToTop
                model: ScriptModel {
                    values: root.entries
                    objectProp: "id"
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
                interactive: root.entries.length > root.maxVisible
                boundsBehavior: Flickable.StopAtBounds
                cacheBuffer: 240

                onCurrentIndexChanged: if (currentIndex >= 0)
                    positionViewAtIndex(currentIndex, ListView.Contain)
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

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    width: 4
                    interactive: false
                    contentItem: Rectangle {
                        implicitWidth: 4
                        radius: 2
                        color: Palette.Theme.accent
                        opacity: parent.active ? 0.6 : 0.25
                    }
                    background: Item {}
                }

                delegate: Item {
                    id: row

                    required property var modelData
                    required property int index

                    readonly property bool image: root.isImage(modelData)
                    readonly property string swatch: root.colorOf(modelData)

                    width: ListView.view.width
                    height: root.itemH

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 10
                        spacing: 12

                        // Thumbnail for images, color swatch for color
                        // codes, otherwise a kind glyph on a tonal disc.
                        Rectangle {
                            Layout.preferredWidth: row.image ? 56 : 36
                            Layout.preferredHeight: 36
                            Layout.alignment: Qt.AlignVCenter
                            radius: row.image ? Palette.Theme.radiusSmall : 18
                            color: row.swatch !== "" ? row.swatch : (row.index === root.selected ? Palette.Theme.accent : Palette.Theme.surfaceContainerHighest)
                            clip: true

                            Behavior on color {
                                ColorMotion {}
                            }

                            Image {
                                id: thumb
                                anchors.fill: parent
                                visible: row.image && status === Image.Ready
                                // previewsReady re-triggers the load once the
                                // service has decoded the file.
                                source: !row.image ? "" : "file://" + (row.modelData.pinned ? root.service.pinPath(row.modelData.pid) : root.service.previewPath(row.modelData.id)) + "?" + root.service.previewsReady
                                sourceSize.width: 112
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: false
                            }

                            Text {
                                anchors.centerIn: parent
                                visible: row.swatch === "" && !thumb.visible
                                text: root.kindIcon(row.modelData)
                                color: row.index === root.selected ? Palette.Theme.accentText : Palette.Theme.textSecondary
                                font.family: Palette.Theme.fontIcons
                                font.weight: Palette.Theme.iconWeight
                                font.pixelSize: Palette.Theme.iconSizeSmall
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: root.isBinary(row.modelData) ? root.describe(row.modelData) : root.highlight(row.modelData.text)
                                textFormat: root.isBinary(row.modelData) ? Text.PlainText : Text.StyledText
                                color: Palette.Theme.textPrimary
                                font.family: Palette.Theme.fontSans
                                font.pixelSize: Palette.Theme.fontSizeBody
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            Text {
                                Layout.fillWidth: true
                                text: (row.modelData.pinned ? "Pinned  ·  " : "") + (root.isLink(row.modelData) ? "Link" : (row.swatch !== "" ? "Color" : (root.isBinary(row.modelData) ? "Image" : row.modelData.text.length + " characters" + (/\n/.test(row.modelData.text) ? "  ·  " + row.modelData.text.split("\n").length + " lines" : ""))))
                                color: row.modelData.pinned ? Palette.Theme.accent : Palette.Theme.textMuted
                                font.family: Palette.Theme.fontSans
                                font.pixelSize: Palette.Theme.fontSizeXs
                                elide: Text.ElideRight
                            }
                        }

                        // Pin: always shown (in accent) on pinned items,
                        // otherwise only on the selected row.
                        IconButton {
                            icon: "push_pin"
                            implicitWidth: 30
                            implicitHeight: 30
                            Layout.alignment: Qt.AlignVCenter
                            iconColor: row.modelData.pinned ? Palette.Theme.accent : Palette.Theme.textSecondary
                            opacity: row.modelData.pinned || row.index === root.selected ? 1 : 0
                            visible: opacity > 0.01
                            onClicked: root.togglePin(row.index)

                            Behavior on opacity {
                                EffectMotion {}
                            }
                        }

                        IconButton {
                            icon: "delete_outline"
                            implicitWidth: 30
                            implicitHeight: 30
                            Layout.alignment: Qt.AlignVCenter
                            opacity: row.index === root.selected ? 1 : 0
                            visible: opacity > 0.01
                            onClicked: root.remove(row.index)

                            Behavior on opacity {
                                EffectMotion {}
                            }
                        }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        anchors.rightMargin: 80
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onPositionChanged: mouse => root.hoverSelect(rowMouse, mouse, row.index)
                        onClicked: root.copy(row.index)
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
                    text: "content_paste_search"
                    color: Palette.Theme.textMuted
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
                    selectByMouse: true
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
                        text: "Search clipboard history"
                        color: Palette.Theme.textMuted
                        font: parent.font
                    }
                }

                Text {
                    text: root.entries.length
                    visible: root.entries.length > 0
                    color: Palette.Theme.textMuted
                    font.family: Palette.Theme.fontMono
                    font.pixelSize: Palette.Theme.fontSizeXs
                    Layout.alignment: Qt.AlignVCenter
                }

                IconButton {
                    icon: search.text !== "" ? "close" : "delete_outline"
                    Layout.alignment: Qt.AlignVCenter
                    onClicked: {
                        if (search.text !== "")
                            search.text = "";
                        else
                            root.service.clear();
                        search.forceActiveFocus();
                    }
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
