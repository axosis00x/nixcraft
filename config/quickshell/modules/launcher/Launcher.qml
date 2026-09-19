import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../theme" as Palette
import "../../components/material"

// Note: DesktopEntries / DesktopEntry are part of the base "Quickshell"
// module, already imported above — no extra import line is needed.

Item {
    id: root

    anchors.fill: parent
    visible: false

    property real maxWidth: 4000
    property var controlCenter: null
    property var serviceManager: null
    property var shaderService: null
    property var wayclickService: null
    property var widgetsService: null

    readonly property int itemH: 56

    // ── slash commands ───────────────────────────────────────────
    // Typing "/" surfaces this palette; typing "/<cmd>" locks the list into
    // that command's own items (still filterable by whatever follows).
    readonly property var commands: [
        { cmd: "shaders", label: "Shaders", icon: "", desc: "Change the screen shader" },
        { cmd: "sounds", label: "Sound Packs", icon: "", desc: "Change the wayclick sound pack" },
        { cmd: "widgets", label: "Widgets", icon: "widgets", desc: "Toggle desktop widgets" }
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

    readonly property var commandItems: commands.filter(c => commandWord === "" || c.cmd.indexOf(commandWord) !== -1 || c.label.toLowerCase().indexOf(commandWord) !== -1)

    readonly property var allShaders: shaderService ? shaderService.shaders : []
    readonly property var shaderItems: {
        var f = commandArg.trim().toLowerCase();
        return f === "" ? allShaders : allShaders.filter(s => shaderService.displayName(s).toLowerCase().indexOf(f) !== -1);
    }

    readonly property var allPacks: wayclickService ? wayclickService.packs : []
    readonly property var packItems: {
        var f = commandArg.trim().toLowerCase();
        return f === "" ? allPacks : allPacks.filter(p => wayclickService.displayName(p).toLowerCase().indexOf(f) !== -1);
    }

    readonly property var allWidgets: widgetsService ? widgetsService.widgets : []
    readonly property var widgetItems: {
        var f = commandArg.trim().toLowerCase();
        return f === "" ? allWidgets : allWidgets.filter(w => w.label.toLowerCase().indexOf(f) !== -1);
    }

    readonly property var currentList: {
        switch (mode) {
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
        case "commands":
            return "Type a command…";
        default:
            return "Search, calculate or run";
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
        default:
            return allApps.length === 0 ? "No applications found" : "No results for '" + query + "'";
        }
    }

    implicitWidth: Math.max(360, Math.min(maxWidth - 32, 430))
    // Fixed height (always room for maxVisible rows) rather than sizing to the
    // current result count — a count that changes on every keystroke would
    // otherwise retrigger the shared stage's grow/shrink animation constantly
    // while typing.
    implicitHeight: searchRow.height + maxVisible * itemH + 8

    // ── IPC ───────────────────────────────────────────────────────
    signal aboutToOpen
    signal aboutToClose

    IpcHandler {
        target: "launcher"
        function toggle(): void {
            if (root.visible)
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

    // ── app data ──────────────────────────────────────────────────
    property string query: ""
    property int selected: 0
    property var allApps: []
    property var displayApps: []

    readonly property int maxVisible: 5
    readonly property int visibleCount: Math.min(root.displayApps.length, root.maxVisible)

    function rebuildApps() {
        var entries = [...DesktopEntries.applications.values].filter(d => d && d.name && !d.noDisplay).sort((a, b) => a.name.localeCompare(b.name));

        allApps = entries;
        filterApps();
    }

    function filterApps() {
        var q = query.trim().toLowerCase();
        if (q === "") {
            displayApps = allApps;
        } else {
            displayApps = allApps.filter(d => {
                var name = (d.name || "").toLowerCase();
                var comment = (d.comment || "").toLowerCase();
                var keywords = (d.keywords || []).join(" ").toLowerCase();
                return name.indexOf(q) !== -1 || comment.indexOf(q) !== -1 || keywords.indexOf(q) !== -1;
            });
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

    onModeChanged: {
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
        var commandText = entry.command ? entry.command.join(" ").toLowerCase() : "";
        var entryName = (entry.name || "").toLowerCase();
        if (entryName === "uuctl" || commandText.indexOf("uuctl") !== -1) {
            closeLauncher(true);
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

    // Single source of truth for launcher keyboard shortcuts — shared by
    // both the search field and the list so behavior can't drift between them.
    function handleKey(event) {
        switch (event.key) {
        case Qt.Key_Up:
            event.accepted = true;
            moveSelection(-1);
            return true;
        case Qt.Key_Down:
            event.accepted = true;
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
            if (mode !== "apps")
                searchInput.text = "";
            else
                closeLauncher();
            return true;
        default:
            return false;
        }
    }

    Component {
        id: appDelegate

        Item {
            required property var modelData
            required property int index

            readonly property int absoluteIndex: index

            width: ListView.view.width
            height: 56

            Rectangle {
                anchors {
                    fill: parent
                    leftMargin: 6
                    rightMargin: 6
                    topMargin: 2
                    bottomMargin: 2
                }
                radius: 16
                color: {
                    if (absoluteIndex === root.selected || rowHover.containsMouse)
                        return Palette.Theme.surfaceContainerHigh;
                    return "transparent";
                }
                border.width: 0
                Behavior on color {
                    ColorAnimation {
                        duration: 100
                    }
                }
            }

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: 12
                    rightMargin: 12
                }
                spacing: 12

                Rectangle {
                    implicitWidth: 32
                    implicitHeight: 32
                    radius: 10
                    color: Palette.Theme.surfaceContainerHighest
                    Layout.alignment: Qt.AlignVCenter

                    IconImage {
                        id: appIcon
                        anchors.centerIn: parent
                        width: 20
                        height: 20
                        source: modelData.icon ? Quickshell.iconPath(modelData.icon, true) : ""
                        smooth: true
                        mipmap: true
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: appIcon.status !== Image.Ready
                        text: ""
                        font.family: Palette.Theme.fontIcons
                        font.pixelSize: 18
                        color: Palette.Theme.textSecondary
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        Layout.fillWidth: true
                        text: (modelData && modelData.name) ? modelData.name : ""
                        color: Palette.Theme.textPrimary
                        font.family: Palette.Theme.fontSans
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: (modelData && modelData.comment) ? modelData.comment : ""
                        visible: text !== ""
                        color: Palette.Theme.textMuted
                        font.family: Palette.Theme.fontSans
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                }
            }

            MouseArea {
                id: rowHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPositionChanged: {
                    if (root.selected !== absoluteIndex) {
                        root.selected = absoluteIndex;
                    }
                }
                onClicked: {
                    root.selected = absoluteIndex;
                    root.launchApp(modelData);
                }
            }
        }
    }

    // Shared row for the command palette, shader list and sound-pack list —
    // same layout as appDelegate but with a glyph icon instead of a desktop
    // icon image, and an active-item checkmark instead of nothing.
    Component {
        id: commandDelegate

        Item {
            required property var modelData
            required property int index

            readonly property bool isCommand: root.mode === "commands"
            readonly property bool isShader: root.mode === "shaders"
            readonly property bool isSound: root.mode === "sounds"
            readonly property bool isWidget: root.mode === "widgets"
            readonly property bool widgetEnabled: isWidget && root.widgetsService && modelData && modelData.id ? root.widgetsService.isEnabled(modelData.id) : false

            readonly property string rowIcon: isCommand ? (modelData && modelData.icon ? modelData.icon : "") : (isShader ? "" : (isSound ? "" : "widgets"))
            readonly property string rowPrimary: isCommand ? (modelData && modelData.label ? modelData.label : "") : (isShader ? (root.shaderService && modelData ? root.shaderService.displayName(modelData) : "") : (isSound ? (root.wayclickService && modelData ? root.wayclickService.displayName(modelData) : "") : (modelData && modelData.label ? modelData.label : "")))
            readonly property string rowSecondary: isCommand ? (modelData && modelData.desc ? modelData.desc : "") : (isShader ? (rowActive ? "Active" : (index === root.selected ? "Previewing" : "")) : "")
            readonly property bool rowActive: isShader ? (root.shaderService && modelData ? modelData === root.shaderService.activeShader : false) : (isSound ? (root.wayclickService && modelData ? modelData === root.wayclickService.activePack : false) : widgetEnabled)

            width: ListView.view.width
            height: 56

            Rectangle {
                anchors {
                    fill: parent
                    leftMargin: 6
                    rightMargin: 6
                    topMargin: 2
                    bottomMargin: 2
                }
                radius: 16
                color: {
                    if (index === root.selected || commandRowHover.containsMouse)
                        return Palette.Theme.surfaceContainerHigh;
                    return "transparent";
                }
                border.width: 0
                Behavior on color {
                    ColorAnimation {
                        duration: 100
                    }
                }
            }

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: 12
                    rightMargin: 12
                }
                spacing: 12

                Rectangle {
                    implicitWidth: 32
                    implicitHeight: 32
                    radius: 10
                    color: Palette.Theme.surfaceContainerHighest
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        anchors.centerIn: parent
                        text: rowIcon
                        font.family: Palette.Theme.fontIcons
                        font.pixelSize: 18
                        color: Palette.Theme.textSecondary
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        Layout.fillWidth: true
                        text: rowPrimary
                        color: Palette.Theme.textPrimary
                        font.family: Palette.Theme.fontSans
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }

                    Text {
                        Layout.fillWidth: true
                        text: rowSecondary
                        visible: text !== ""
                        color: Palette.Theme.textMuted
                        font.family: Palette.Theme.fontSans
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                }

                Text {
                    visible: rowActive || isWidget
                    text: isWidget ? (widgetEnabled ? "toggle_on" : "toggle_off") : ""
                    font.family: Palette.Theme.fontIcons
                    font.pixelSize: isWidget ? 22 : 14
                    color: isWidget && !widgetEnabled ? Palette.Theme.textMuted : Palette.Theme.accent
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            MouseArea {
                id: commandRowHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPositionChanged: {
                    if (root.selected !== index) {
                        root.selected = index;
                    }
                }
                onClicked: {
                    root.selected = index;
                    root.activateIndex(index);
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
            root.controlCenter.closeControlCenter(true);
        if (root.visible)
            return;
        aboutToOpen();
        searchInput.text = "";
        query = "";
        selected = 0;
        visible = true;
        searchInput.forceActiveFocus();
    }

    function closeLauncher(immediate) {
        if (!root.visible)
            return;
        if (shaderService && shaderService.isPreviewing) {
            shaderService.cancelPreview();
        }
        aboutToClose();
        if (immediate) {
            closeTimer.stop();
            root.visible = false;
            return;
        }
        closeTimer.restart();
    }

    Timer {
        id: closeTimer
        interval: 180
        onTriggered: root.visible = false
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

            // ── search bar ────────────────────────────────────────
            Item {
                id: searchRow
                Layout.fillWidth: true
                height: 62

                Rectangle {
                    id: searchField
                    anchors {
                        fill: parent
                        leftMargin: 10
                        rightMargin: 10
                        topMargin: 10
                        bottomMargin: 8
                    }
                    radius: 16
                    color: Palette.Theme.surfaceContainerHigh
                    border.width: 0
                }

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: 22
                        rightMargin: 18
                        topMargin: 10
                        bottomMargin: 8
                    }
                    spacing: 12

                    // leading search icon
                    Text {
                        text: ""
                        font.family: Palette.Theme.fontIcons
                        font.pixelSize: 18
                        color: Palette.Theme.textMuted
                        Layout.alignment: Qt.AlignVCenter
                    }

                    // text input
                    TextInput {
                        id: searchInput
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        Keys.priority: Keys.BeforeItem
                        font.family: Palette.Theme.fontMono
                        font.pixelSize: 13
                        color: Palette.Theme.textPrimary
                        selectionColor: Palette.Theme.accent + "44"
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
                        }

                        onTextChanged: root.query = text

                        Keys.onPressed: event => root.handleKey(event)
                    }

                    // clear button — fades in/out instead of popping
                    IconButton {
                        icon: ""
                        opacity: searchInput.text !== "" ? 1 : 0
                        visible: opacity > 0
                        Layout.alignment: Qt.AlignVCenter
                        onClicked: {
                            searchInput.text = "";
                            searchInput.forceActiveFocus();
                        }

                        Behavior on opacity {
                            NumberAnimation {
                                duration: 120
                            }
                        }
                    }
                }
            }

            Item {
                id: listPanel
                Layout.fillWidth: true
                Layout.fillHeight: true

                Item {
                    anchors.fill: parent
                    visible: root.currentList.length === 0

                    Text {
                        anchors.centerIn: parent
                        text: root.emptyStateText
                        color: Palette.Theme.textMuted
                        font.family: Palette.Theme.fontMono
                        font.pixelSize: 12
                    }
                }

                ListView {
                    id: appList
                    anchors.fill: parent
                    clip: true
                    model: root.currentList
                    currentIndex: root.selected
                    Keys.priority: Keys.BeforeItem
                    highlightFollowsCurrentItem: true
                    preferredHighlightBegin: 0
                    preferredHighlightEnd: height
                    interactive: root.currentList.length > root.maxVisible
                    boundsBehavior: Flickable.StopAtBounds
                    spacing: 0
                    focus: true
                    keyNavigationEnabled: true
                    reuseItems: true
                    cacheBuffer: 240

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
                                NumberAnimation {
                                    duration: 120
                                }
                            }
                        }
                        background: Item {}
                    }

                    Keys.onPressed: event => root.handleKey(event)

                    delegate: root.mode === "apps" ? appDelegate : commandDelegate
                }
            }
        }
}
