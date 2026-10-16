import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../theme" as Palette
import "../../components/material"

// Note: DesktopEntries / DesktopEntry and ScriptModel are part of the base
// "Quickshell" module, already imported above.

// App launcher: search field at the bottom, fuzzy-ranked results above it
// (best match nearest), boosted by launch count.
Item {
    id: root

    visible: false
    // Still visible while the close delay runs, but on its way out.
    readonly property bool closing: closeTimer.running

    property real maxWidth: 4000
    property var controlCenter: null
    property var serviceManager: null
    property var shaderService: null
    property var wayclickService: null
    property var widgetsService: null
    property var settingsWindow: null

    readonly property int itemH: 56
    readonly property int maxVisible: 5

    // ── slash commands ───────────────────────────────────────────
    // Typing "/" surfaces this palette; typing "/<cmd>" locks the list into
    // that command's own items (still filterable by whatever follows).
    readonly property var commands: [
        { cmd: "shaders", label: "Shaders", icon: "blur_on", desc: "Change the screen shader" },
        { cmd: "sounds", label: "Sound Packs", icon: "keyboard", desc: "Change the wayclick sound pack" },
        { cmd: "widgets", label: "Widgets", icon: "widgets", desc: "Toggle desktop widgets" },
        { cmd: "settings", label: "Settings", icon: "settings", desc: "Open a settings page" }
    ]

    readonly property bool isCommandInput: query.startsWith("/")
    readonly property string commandRest: isCommandInput ? query.slice(1) : ""
    readonly property string commandWord: commandRest.split(/\s+/)[0].toLowerCase()
    readonly property string commandArg: commandRest.slice(commandWord.length).replace(/^\s+/, "")
    readonly property var matchedCommand: commands.find(c => c.cmd === commandWord) || null

    readonly property string mode: {
        if (!isCommandInput)
            return "apps";
        return matchedCommand ? matchedCommand.cmd : "commands";
    }

    // What the current list is being filtered by (drives match highlighting).
    readonly property string filterText: mode === "apps" ? query.trim() : (mode === "commands" ? commandWord : commandArg.trim())

    readonly property var commandItems: rank(commands, c => c.label, commandWord, c => c.cmd)

    readonly property var allShaders: shaderService ? shaderService.shaders : []
    readonly property var shaderItems: rank(allShaders, s => shaderService.displayName(s), commandArg.trim())

    readonly property var allPacks: wayclickService ? wayclickService.packs : []
    readonly property var packItems: rank(allPacks, p => wayclickService.displayName(p), commandArg.trim())

    readonly property var allWidgets: widgetsService ? widgetsService.widgets : []
    readonly property var widgetItems: rank(allWidgets, w => w.label, commandArg.trim())

    // One entry per settings page; picking one opens the settings window there.
    readonly property var allSettings: settingsWindow ? settingsWindow.categories.map(c => ({
                id: c.id,
                label: c.title,
                icon: c.icon,
                desc: settingsWindow.pageSummary(c.id)
            })) : []
    readonly property var settingsItems: rank(allSettings, c => c.label, commandArg.trim())

    // The list follows `listMode`, switched together with the row template
    // in switchList(); changing both at once built "/" command rows with the
    // app template, which showed nothing.
    property string listMode: "apps"
    // Row animations stay off: with big reorders (each keystroke re-ranks
    // dozens of apps) they left rows invisible or in the wrong slots.
    // Results show instantly instead.
    readonly property bool listAnimated: false

    readonly property var currentList: {
        switch (listMode) {
        case "apps":
            return displayApps;
        case "commands":
            return commandItems;
        case "shaders":
            return shaderItems;
        case "sounds":
            return packItems;
        case "widgets":
            return widgetItems;
        case "settings":
            return settingsItems;
        default:
            return [];
        }
    }

    readonly property string placeholderText: {
        switch (mode) {
        case "shaders":
            return "Search shaders…";
        case "sounds":
            return "Search sound packs…";
        case "widgets":
            return "Search widgets…";
        case "settings":
            return "Search settings…";
        case "commands":
            return "Type a command…";
        default:
            return "Search apps, or / for commands";
        }
    }

    readonly property string emptyStateText: {
        switch (mode) {
        case "commands":
            return "No matching commands";
        case "shaders":
            return allShaders.length === 0 ? "No shaders found" : "No results for '" + commandArg + "'";
        case "sounds":
            return allPacks.length === 0 ? "No sound packs found" : "No results for '" + commandArg + "'";
        case "widgets":
            return allWidgets.length === 0 ? "No widgets found" : "No results for '" + commandArg + "'";
        case "settings":
            return "No results for '" + commandArg + "'";
        default:
            return allApps.length === 0 ? "No applications found" : "No results for '" + query + "'";
        }
    }

    // Grows and shrinks with the results (the stage springs to follow), so
    // the field stays put at the bottom and the list rises out of it.
    readonly property int visibleRows: Math.max(1, Math.min(maxVisible, currentList.length))
    implicitWidth: Math.min(maxWidth - 32, Palette.Theme.listPanelWidth)
    implicitHeight: searchRow.height + visibleRows * itemH + listPanel.Layout.topMargin

    // ── IPC ───────────────────────────────────────────────────────
    signal aboutToOpen
    signal aboutToClose

    IpcHandler {
        target: "launcher"
        function toggle(): void {
            if (root.visible && !root.closing)
                root.closeLauncher();
            else
                root.openLauncher();
        }
        function open(): void {
            root.openLauncher();
        }
        function close(): void {
            root.closeLauncher();
        }
        function setQuery(q: string): void {
            root.openLauncher();
            searchInput.text = q;
        }
        function next(): void {
            root.moveSelection(1);
        }
        function prev(): void {
            root.moveSelection(-1);
        }
        function select(): void {
            root.activateSelected();
        }
    }

    // ── matching ──────────────────────────────────────────────────
    function isBoundary(t, i) {
        return i === 0 || /[\s\-_.\/]/.test(t[i - 1]);
    }

    // Scores `text` against `query`, or null if it doesn't match. Exact,
    // prefix and word-start substrings rank highest; otherwise the query's
    // letters must appear in order, scored up for consecutive runs and word
    // starts and down for gaps, and loose scatters are rejected.
    function fuzzy(query, text) {
        var q = (query || "").toLowerCase();
        var t = (text || "").toLowerCase();
        if (q === "")
            return { score: 0, indices: [] };
        if (t === "")
            return null;
        var at = t.indexOf(q);
        if (at !== -1) {
            var run = [];
            for (var k = 0; k < q.length; k++)
                run.push(at + k);
            var score = t === q ? 1000 : (at === 0 ? 800 : (isBoundary(t, at) ? 600 : 400 - Math.min(at, 100)));
            return { score: score, indices: run };
        }
        var indices = [];
        var total = 0;
        var from = 0;
        for (var qi = 0; qi < q.length; qi++) {
            var found = t.indexOf(q[qi], from);
            if (found === -1)
                return null;
            total += 10;
            if (indices.length > 0 && found === indices[indices.length - 1] + 1)
                total += 15;
            if (isBoundary(t, found))
                total += 20;
            total -= Math.min(found - from, 10);
            indices.push(found);
            from = found + 1;
        }
        if (total < q.length * 8)
            return null;
        return { score: Math.min(total, 300), indices: indices };
    }

    // Filters and orders `list` by how well `label(item)` (or, if given,
    // `alt(item)`) matches `q`; an empty query keeps the original order.
    function rank(list, label, q, alt) {
        if (!q)
            return list.slice();
        var scored = [];
        list.forEach(item => {
            var m = fuzzy(q, label(item));
            var best = m ? m.score : -1;
            if (alt) {
                var a = fuzzy(q, alt(item));
                if (a && a.score > best)
                    best = a.score;
            }
            if (best >= 0)
                scored.push({ item: item, score: best });
        });
        scored.sort((a, b) => b.score - a.score);
        return scored.map(r => r.item);
    }

    function escapeHtml(s) {
        return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }

    // `text` as StyledText with the letters matching the filter picked out.
    function highlight(text) {
        text = text || "";
        var m = filterText !== "" ? fuzzy(filterText, text) : null;
        if (!m || m.indices.length === 0)
            return escapeHtml(text);
        var accent = String(Palette.Theme.accent);
        var out = "";
        for (var i = 0; i < text.length; i++) {
            var ch = escapeHtml(text[i]);
            out += m.indices.indexOf(i) !== -1 ? "<font color=\"" + accent + "\"><b>" + ch + "</b></font>" : ch;
        }
        return out;
    }

    // ── app data ──────────────────────────────────────────────────
    property string query: ""
    property int selected: 0
    property var allApps: []
    property var displayApps: []

    // Launch counts per desktop entry id: frequent apps float to the top of
    // the unfiltered list and win ties while filtering.
    FileView {
        id: usageFile
        path: Quickshell.cachePath("launcher-usage.json")
        watchChanges: false
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: usage
            property var counts: ({})
        }
    }

    function launchCount(entry) {
        return (usage.counts && usage.counts[entry.id]) || 0;
    }

    function recordLaunch(entry) {
        var next = Object.assign({}, usage.counts);
        next[entry.id] = (next[entry.id] || 0) + 1;
        usage.counts = next;
        usageFile.writeAdapter();
    }

    function rebuildApps() {
        allApps = [...DesktopEntries.applications.values].filter(d => d && d.name && !d.noDisplay).sort((a, b) => a.name.localeCompare(b.name));
        filterApps();
    }

    function filterApps() {
        var q = query.trim();
        if (isCommandInput) {
            selected = 0;
            return;
        }
        if (q === "") {
            displayApps = allApps.slice().sort((a, b) => launchCount(b) - launchCount(a) || a.name.localeCompare(b.name));
        } else {
            var lower = q.toLowerCase();
            var scored = [];
            allApps.forEach(d => {
                var best = -1;
                var m = fuzzy(q, d.name);
                if (m)
                    best = m.score;
                m = fuzzy(q, d.genericName);
                if (m && m.score * 0.8 > best)
                    best = m.score * 0.8;
                // Keywords and descriptions only count as plain substrings;
                // fuzzy letters across long text match almost anything.
                if (best < 150 && ((d.keywords || []).join(" ").toLowerCase().indexOf(lower) !== -1 || (d.comment || "").toLowerCase().indexOf(lower) !== -1))
                    best = 150;
                if (best >= 0)
                    scored.push({ entry: d, score: best + Math.min(launchCount(d), 20) * 4 });
            });
            scored.sort((a, b) => b.score - a.score || a.entry.name.localeCompare(b.entry.name));
            displayApps = scored.map(r => r.entry);
        }
        selected = 0;
    }

    onQueryChanged: {
        filterApps();
        if (mode === "shaders") {
            syncShaderSelection();
            updateShaderPreview();
        } else {
            selected = 0;
        }
        Qt.callLater(root.resetList);
    }

    // Rebuild the rows instead of letting the list apply a burst of moves:
    // re-ranking reorders dozens of rows per keystroke, which left the
    // bottom-to-top list scrolled wrong (gaps) until the pointer moved.
    function resetList() {
        appList.model = null;
        appList.model = appModel;
        // Re-bind: reattaching the model resets currentIndex, and a plain
        // assignment would break the binding hover selection relies on.
        appList.currentIndex = Qt.binding(() => root.selected);
        if (selected <= 0)
            appList.positionViewAtBeginning();
        else
            appList.positionViewAtIndex(selected, ListView.Contain);
    }

    function syncShaderSelection() {
        if (mode === "shaders" && shaderService && currentList === shaderItems && currentList.length > 0) {
            if (commandArg.trim() === "" && shaderService.activeShader) {
                var idx = currentList.indexOf(shaderService.activeShader);
                if (idx >= 0) {
                    selected = idx;
                    appList.positionViewAtIndex(selected, ListView.Contain);
                    return;
                }
            }
            if (selected < 0 || selected >= currentList.length) {
                selected = 0;
            }
            appList.positionViewAtIndex(selected, ListView.Contain);
        }
    }

    function updateShaderPreview() {
        if (mode === "shaders" && shaderService && currentList === shaderItems) {
            var list = currentList;
            if (list.length > 0 && selected >= 0 && selected < list.length) {
                shaderService.preview(list[selected]);
            } else if (list.length === 0 && shaderService.isPreviewing) {
                shaderService.cancelPreview();
            }
        }
    }

    onModeChanged: Qt.callLater(root.switchList)

    // Runs after the mode change settles: empty the list, swap the row
    // template, then load the new data, so rows never get the other kind's
    // data (and no binding loop on currentList).
    function switchList() {
        if (listMode === mode)
            return;
        listMode = "";
        appList.delegate = mode === "apps" ? appDelegate : commandDelegate;
        listMode = mode;
        if (mode === "shaders") {
            if (shaderService) {
                shaderService.refresh();
                syncShaderSelection();
                updateShaderPreview();
            }
        } else {
            if (shaderService && shaderService.isPreviewing) {
                shaderService.cancelPreview();
            }
        }
        if (mode === "apps")
            filterApps();
    }

    onSelectedChanged: {
        if (mode === "shaders") {
            updateShaderPreview();
        }
    }

    onCurrentListChanged: {
        if (mode === "shaders") {
            syncShaderSelection();
            updateShaderPreview();
        }
    }

    onVisibleChanged: {
        if (!visible && shaderService && shaderService.isPreviewing) {
            shaderService.cancelPreview();
        }
    }

    Connections {
        target: root.shaderService
        function onActiveShaderChanged(): void {
            if (root.mode === "shaders" && root.shaderService && !root.shaderService.isPreviewing) {
                root.syncShaderSelection();
                root.updateShaderPreview();
            }
        }
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged(): void {
            root.rebuildApps();
        }
    }

    // ── launch helper ─────────────────────────────────────────────
    function launchApp(entry) {
        recordLaunch(entry);
        var commandText = entry.command ? entry.command.join(" ").toLowerCase() : "";
        var entryName = (entry.name || "").toLowerCase();
        if (entryName === "uuctl" || commandText.indexOf("uuctl") !== -1) {
            closeLauncher();
            if (serviceManager)
                serviceManager.open();
            return;
        }
        closeLauncher();
        if (entry.runInTerminal && entry.command && entry.command.length > 0)
            terminalLaunch.exec(["kitty", "-e"].concat(entry.command));
        else
            entry.execute();
    }

    // Enter a command's slash prefix into the input and keep typing to
    // filter that command's own list, without needing a separate "confirm"
    // step — mirrors how typing the full command name locks in the mode.
    function commitCommand(command) {
        searchInput.text = "/" + command.cmd + " ";
        searchInput.cursorPosition = searchInput.text.length;
    }

    function activateIndex(index) {
        var list = currentList;
        if (index < 0 || index >= list.length)
            return;
        switch (mode) {
        case "apps":
            launchApp(list[index]);
            return;
        case "commands":
            commitCommand(list[index]);
            return;
        case "shaders":
            shaderService.apply(list[index]);
            closeLauncher();
            return;
        case "sounds":
            wayclickService.apply(list[index]);
            closeLauncher();
            return;
        case "widgets":
            // Toggling is non-exclusive (unlike picking a shader/sound), so
            // stay open — the user likely wants to flip more than one.
            widgetsService.toggle(list[index].id);
            return;
        case "settings":
            closeLauncher();
            if (settingsWindow)
                settingsWindow.openPage(list[index].id);
            return;
        }
    }

    function activateSelected() {
        activateIndex(selected);
    }

    function moveSelectionTo(index) {
        var list = currentList;
        if (list.length === 0)
            return;
        selected = Math.max(0, Math.min(list.length - 1, index));
        appList.positionViewAtIndex(selected, ListView.Contain);
    }

    function moveSelection(delta) {
        moveSelectionTo(selected + delta);
    }

    // Hover only selects when the pointer itself moves: rows sliding under
    // a resting cursor while filtering must not steal the selection from
    // the best match (Enter would launch the wrong app).
    property point lastPointer: Qt.point(-1, -1)

    function hoverSelect(item, mouse, index) {
        var p = item.mapToItem(null, mouse.x, mouse.y);
        if (p.x === lastPointer.x && p.y === lastPointer.y)
            return;
        lastPointer = p;
        if (selected !== index)
            selected = index;
    }

    // Single source of truth for launcher keyboard shortcuts — shared by
    // both the search field and the list so behavior can't drift between them.
    // The list runs bottom-to-top, so Up steps to the next result.
    function handleKey(event) {
        switch (event.key) {
        case Qt.Key_Up:
            event.accepted = true;
            moveSelection(1);
            return true;
        case Qt.Key_Down:
            event.accepted = true;
            moveSelection(-1);
            return true;
        case Qt.Key_Tab:
            event.accepted = true;
            if (mode === "commands" && currentList.length > 0)
                commitCommand(currentList[selected]);
            else
                moveSelection(1);
            return true;
        case Qt.Key_Home:
            event.accepted = true;
            moveSelectionTo(0);
            return true;
        case Qt.Key_End:
            event.accepted = true;
            moveSelectionTo(currentList.length - 1);
            return true;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            event.accepted = true;
            activateSelected();
            return true;
        case Qt.Key_Escape:
            event.accepted = true;
            if (searchInput.text !== "")
                searchInput.text = "";
            else
                closeLauncher();
            return true;
        default:
            return false;
        }
    }

    // A row's leading icon: the app's own icon, or a glyph on a tonal disc.
    component RowIcon: Item {
        property string iconSource: ""
        property string glyph: ""
        property bool active: false

        implicitWidth: 36
        implicitHeight: 36
        Layout.alignment: Qt.AlignVCenter

        IconImage {
            id: image
            anchors.centerIn: parent
            implicitSize: 32
            visible: parent.iconSource !== "" && status === Image.Ready
            source: parent.iconSource
            smooth: true
            mipmap: true
        }

        Rectangle {
            anchors.fill: parent
            visible: !image.visible
            radius: parent.active ? Palette.Theme.radiusMedium : width / 2
            color: parent.active ? Palette.Theme.accent : Palette.Theme.surfaceContainerHighest

            Behavior on radius {
                SpatialMotion {}
            }
            Behavior on color {
                ColorMotion {}
            }

            Text {
                anchors.centerIn: parent
                text: parent.parent.glyph !== "" ? parent.parent.glyph : "apps"
                font.family: Palette.Theme.fontIcons
                font.weight: Palette.Theme.iconWeight
                font.pixelSize: Palette.Theme.iconSize
                color: parent.parent.active ? Palette.Theme.accentText : Palette.Theme.textSecondary
            }
        }
    }

    component RowText: ColumnLayout {
        property string primary: ""
        property string secondary: ""

        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: 2

        Text {
            Layout.fillWidth: true
            text: root.highlight(parent.primary)
            textFormat: Text.StyledText
            color: Palette.Theme.textPrimary
            font.family: Palette.Theme.fontSans
            font.pixelSize: Palette.Theme.fontSizeBody
            font.weight: Font.Medium
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            text: parent.secondary
            visible: text !== ""
            color: Palette.Theme.textMuted
            font.family: Palette.Theme.fontSans
            font.pixelSize: Palette.Theme.fontSizeXs
            elide: Text.ElideRight
        }
    }

    Component {
        id: appDelegate

        Item {
            id: appRow

            required property var modelData
            required property int index

            width: ListView.view.width
            height: root.itemH

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 14

                RowIcon {
                    iconSource: appRow.modelData && appRow.modelData.icon ? Quickshell.iconPath(appRow.modelData.icon, true) : ""
                }

                RowText {
                    primary: appRow.modelData ? appRow.modelData.name : ""
                    secondary: appRow.modelData ? (appRow.modelData.comment || appRow.modelData.genericName || "") : ""
                }
            }

            MouseArea {
                id: appMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPositionChanged: mouse => root.hoverSelect(appMouse, mouse, appRow.index)
                onClicked: {
                    root.selected = appRow.index;
                    root.launchApp(appRow.modelData);
                }
            }
        }
    }

    // Shared row for the command palette, shader list and sound-pack list —
    // same layout as appDelegate but with a glyph icon instead of a desktop
    // icon image, and an active-item mark.
    Component {
        id: commandDelegate

        Item {
            id: commandRow

            required property var modelData
            required property int index

            readonly property bool isCommand: root.mode === "commands"
            readonly property bool isShader: root.mode === "shaders"
            readonly property bool isSound: root.mode === "sounds"
            readonly property bool isWidget: root.mode === "widgets"
            readonly property bool isSettings: root.mode === "settings"
            readonly property bool widgetEnabled: isWidget && root.widgetsService && modelData && modelData.id ? root.widgetsService.isEnabled(modelData.id) : false

            readonly property string rowIcon: isCommand || isSettings ? (modelData && modelData.icon ? modelData.icon : "") : (isShader ? "blur_on" : (isSound ? "keyboard" : "widgets"))
            readonly property string rowPrimary: isCommand ? (modelData && modelData.label ? modelData.label : "") : (isShader ? (root.shaderService && modelData ? root.shaderService.displayName(modelData) : "") : (isSound ? (root.wayclickService && modelData ? root.wayclickService.displayName(modelData) : "") : (modelData && modelData.label ? modelData.label : "")))
            readonly property string rowSecondary: isCommand ? "/" + modelData.cmd + "  ·  " + modelData.desc : (isSettings ? (modelData && modelData.desc ? modelData.desc : "") : (isShader ? (rowActive ? "Active" : (index === root.selected ? "Previewing" : "")) : (isSound && rowActive ? "Active" : "")))
            readonly property bool rowActive: isShader ? (root.shaderService && modelData ? modelData === root.shaderService.activeShader : false) : (isSound ? (root.wayclickService && modelData ? modelData === root.wayclickService.activePack : false) : widgetEnabled)

            width: ListView.view.width
            height: root.itemH

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 14

                RowIcon {
                    glyph: commandRow.rowIcon
                    active: commandRow.rowActive
                }

                RowText {
                    primary: commandRow.rowPrimary
                    secondary: commandRow.rowSecondary
                }

                ToggleSwitch {
                    visible: commandRow.isWidget
                    Layout.alignment: Qt.AlignVCenter
                    checked: commandRow.widgetEnabled
                    onToggled: root.widgetsService.toggle(commandRow.modelData.id)
                }

                Text {
                    visible: commandRow.isCommand
                    text: "keyboard_tab"
                    font.family: Palette.Theme.fontIcons
                    font.weight: Palette.Theme.iconWeight
                    font.pixelSize: Palette.Theme.iconSizeSmall
                    color: Palette.Theme.textMuted
                    opacity: commandRow.index === root.selected ? 1 : 0
                    Layout.alignment: Qt.AlignVCenter

                    Behavior on opacity {
                        EffectMotion {}
                    }
                }
            }

            MouseArea {
                id: commandMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                // Leave the widget toggle its own clicks.
                anchors.rightMargin: commandRow.isWidget ? 70 : 0
                onPositionChanged: mouse => root.hoverSelect(commandMouse, mouse, commandRow.index)
                onClicked: {
                    root.selected = commandRow.index;
                    root.activateIndex(commandRow.index);
                }
            }
        }
    }

    Process {
        id: terminalLaunch
    }

    // ── open / close ──────────────────────────────────────────────
    Component.onCompleted: rebuildApps()

    function openLauncher() {
        if (root.controlCenter && root.controlCenter.visible && typeof root.controlCenter.closeControlCenter === "function")
            root.controlCenter.closeControlCenter();
        if (root.visible && !closing)
            return;
        closeTimer.stop();
        aboutToOpen();
        // Visible first: list changes on a hidden view skip their fade-in
        // and leave rows invisible until something nudges them.
        visible = true;
        searchInput.text = "";
        query = "";
        filterApps();
        selected = 0;
        // Fresh rows every open (rows built while hidden kept stale slots).
        resetList();
        searchInput.forceActiveFocus();
    }

    function closeLauncher(immediate) {
        if (!root.visible)
            return;
        if (shaderService && shaderService.isPreviewing) {
            shaderService.cancelPreview();
        }
        if (!closing)
            aboutToClose();
        if (immediate) {
            closeTimer.stop();
            root.visible = false;
            return;
        }
        if (!closing)
            closeTimer.start();
    }

    Timer {
        id: closeTimer
        interval: 180
        onTriggered: {
            root.visible = false;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── results ───────────────────────────────────────────────
        Item {
            id: listPanel
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 6
            clip: true

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 6
                visible: root.currentList.length === 0
                opacity: visible ? 1 : 0

                Behavior on opacity {
                    EffectMotion {}
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "search_off"
                    color: Palette.Theme.textMuted
                    font.family: Palette.Theme.fontIcons
                    font.weight: Palette.Theme.iconWeight
                    font.pixelSize: Palette.Theme.iconSizeLarge
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.emptyStateText
                    color: Palette.Theme.textMuted
                    font.family: Palette.Theme.fontSans
                    font.pixelSize: Palette.Theme.fontSizeSmall
                }
            }

            ListView {
                id: appList
                anchors.fill: parent
                // Best match sits right above the search field.
                verticalLayoutDirection: ListView.BottomToTop
                // A diffing model: filtering inserts, removes and moves rows
                // (animated below) rather than resetting the whole list.
                model: ScriptModel {
                    id: appModel
                    values: root.currentList
                }
                currentIndex: root.selected
                Keys.priority: Keys.BeforeItem
                // The selection is one tonal highlight gliding between rows
                // (hover moves the selection too), not each row recoloring.
                highlightFollowsCurrentItem: false
                highlight: MovingHighlight {
                    target: appList.currentItem
                    insetX: 6
                    insetY: 2
                    radius: Palette.Theme.radiusMedium
                    color: Palette.Theme.accentTonal
                }
                onCurrentIndexChanged: if (currentIndex >= 0)
                    positionViewAtIndex(currentIndex, ListView.Contain)
                // The panel springs to a new height as results change; keep
                // the selection (normally the best match, at the bottom)
                // pinned in view while it does.
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
                interactive: root.currentList.length > root.maxVisible
                boundsBehavior: Flickable.StopAtBounds
                spacing: 0
                focus: true
                keyNavigationEnabled: false
                cacheBuffer: 240

                // Opacity fades always finish (alwaysRunToEnd): an interrupted
                // fade left rows invisible until the pointer nudged them.
                add: root.listAnimated ? addTransition : null
                property Transition addTransition: Transition {
                    EffectMotion {
                        property: "opacity"
                        alwaysRunToEnd: true
                        from: 0
                        to: 1
                        fast: false
                    }
                }

                remove: root.listAnimated ? removeTransition : null
                property Transition removeTransition: Transition {
                    EffectMotion {
                        property: "opacity"
                        alwaysRunToEnd: true
                        to: 0
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
                        Behavior on opacity {
                            EffectMotion {}
                        }
                    }
                    background: Item {}
                }

                Keys.onPressed: event => root.handleKey(event)

                // Swapped in switchList(), ahead of the data.
                delegate: appDelegate
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

                // Mode glyph: search for apps, the command's own icon in a
                // slash command.
                Text {
                    text: root.mode === "apps" ? "search" : (root.matchedCommand ? root.matchedCommand.icon : "keyboard_command_key")
                    font.family: Palette.Theme.fontIcons
                    font.weight: Palette.Theme.iconWeight
                    font.pixelSize: Palette.Theme.iconSize
                    color: root.mode === "apps" ? Palette.Theme.textMuted : Palette.Theme.accent
                    Layout.alignment: Qt.AlignVCenter

                    Behavior on color {
                        ColorMotion {}
                    }
                }

                TextInput {
                    id: searchInput
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    Keys.priority: Keys.BeforeItem
                    font.family: Palette.Theme.fontSans
                    font.pixelSize: Palette.Theme.fontSizeBody
                    color: Palette.Theme.textPrimary
                    selectionColor: Palette.Theme.accent
                    selectedTextColor: Palette.Theme.accentText
                    clip: true
                    verticalAlignment: TextInput.AlignVCenter
                    // Focusing the field on open (below) would otherwise
                    // leave a blinking caret sitting over the empty
                    // placeholder — only show it once there's real text.
                    cursorVisible: text !== ""

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        text: root.placeholderText
                        font: parent.font
                        color: Palette.Theme.textMuted
                        visible: parent.text === ""
                        elide: Text.ElideRight
                    }

                    onTextChanged: root.query = text

                    Keys.onPressed: event => root.handleKey(event)
                }

                // Result count while filtering.
                Text {
                    visible: root.filterText !== "" && root.currentList.length > 0
                    text: root.currentList.length
                    font.family: Palette.Theme.fontMono
                    font.pixelSize: Palette.Theme.fontSizeXs
                    color: Palette.Theme.textMuted
                    Layout.alignment: Qt.AlignVCenter
                }

                // clear button — fades in/out instead of popping
                IconButton {
                    icon: "close"
                    opacity: searchInput.text !== "" ? 1 : 0
                    visible: opacity > 0
                    Layout.alignment: Qt.AlignVCenter
                    onClicked: {
                        searchInput.text = "";
                        searchInput.forceActiveFocus();
                    }

                    Behavior on opacity {
                        EffectMotion {}
                    }
                }
            }
        }
    }
}
