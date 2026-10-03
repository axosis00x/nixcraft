import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import "../../config/Ui.js" as Ui
import "../../theme" as Palette
import "../../components/material"

Item {
    id: root
    anchors.fill: parent
    visible: false
    focus: visible

    required property var service
    property real maxWidth: 4000
    property real maxHeight: 4000
    property var launcher: null
    property var controlCenter: null
    property var powerMenu: null
    property string query: ""
    property int selected: 0
    readonly property int columns: 4
    readonly property var themes: service ? service.themes.filter(name => name.toLowerCase().indexOf(query.toLowerCase()) !== -1) : []

    implicitWidth: Math.min(maxWidth - 20, Ui.themeOverlayWidth)
    implicitHeight: Math.min(maxHeight - 12, content.implicitHeight + 24)

    signal aboutToOpen
    signal aboutToClose

    IpcHandler {
        target: "theme"
        function toggle(): void {
            root.visible ? root.close() : root.open();
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
            launcher.closeLauncher(true);
        if (controlCenter && controlCenter.visible)
            controlCenter.closeControlCenter(true);
        if (powerMenu && powerMenu.visible)
            powerMenu.closePowerMenu(true);
        query = "";
        selected = 0;
        aboutToOpen();
        visible = true;
        service.refresh();
        forceActiveFocus();
    }

    function close(immediate) {
        if (!visible)
            return;
        aboutToClose();
        if (immediate) {
            closeTimer.stop();
            visible = false;
            return;
        }
        closeTimer.restart();
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

    // A theme's own colors, read from its quickshell.js by ThemeService.
    function paletteFor(themeName) {
        return service && service.palettes ? service.palettes[themeName] : undefined;
    }

    // Five distinct colors for a card: the theme's UI accents first, then its
    // terminal colors to fill in wherever the UI palette repeats itself.
    function swatchesFor(themeName) {
        var pal = paletteFor(themeName);
        if (!pal)
            return [];
        var candidates = [pal.accent, pal.info, pal.success, pal.warning, pal.error, pal.ansi5, pal.ansi4, pal.ansi6, pal.ansi2, pal.ansi3, pal.ansi1];
        var out = [];
        var seen = {};
        for (var i = 0; i < candidates.length && out.length < 5; i++) {
            var c = candidates[i];
            if (!c || seen[c.toLowerCase()])
                continue;
            seen[c.toLowerCase()] = true;
            out.push(c);
        }
        return out;
    }

    function accentFor(themeName) {
        var pal = paletteFor(themeName);
        return pal && pal.accent ? pal.accent : Palette.Theme.accent;
    }

    function handleKey(event) {
        if (event.key === Qt.Key_Escape) {
            close();
            event.accepted = true;
        } else if (event.key === Qt.Key_Left) {
            move(-1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Right) {
            move(1);
            event.accepted = true;
        } else if (event.key === Qt.Key_Up) {
            move(-root.columns);
            event.accepted = true;
        } else if (event.key === Qt.Key_Down) {
            move(root.columns);
            event.accepted = true;
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            apply(selected);
            event.accepted = true;
        }
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Theme"
                    color: Palette.Theme.textTitle
                    font.family: Palette.Theme.fontSans
                    font.pixelSize: Palette.Theme.fontSizeTitle
                    font.weight: Font.DemiBold
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                }
                Text {
                    text: service.activeTheme
                    color: Palette.Theme.textMuted
                    font.family: Palette.Theme.fontMono
                    font.pixelSize: Palette.Theme.fontSizeXs
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            GridLayout {
                columns: root.columns
                columnSpacing: 8
                rowSpacing: 8
                Layout.fillWidth: true

                Repeater {
                    model: root.themes
                    delegate: Rectangle {
                        id: card
                        required property string modelData
                        required property int index
                        readonly property bool isActive: modelData === service.activeTheme
                        readonly property var pal: root.paletteFor(modelData)
                        Layout.fillWidth: true
                        Layout.preferredHeight: 66
                        radius: Palette.Theme.radiusMedium
                        scale: cardMouse.pressed ? 0.94 : (index === root.selected ? 1.025 : 1)
                        Behavior on scale {
                            SpatialMotion {
                                fast: true
                            }
                        }
                        // Uniform cards in the shell's own colors; the theme is
                        // previewed only through its palette strip below. No
                        // outline except on the selected card.
                        color: index === root.selected ? Palette.Theme.surfaceContainerHighest : Palette.Theme.surfaceContainerHigh
                        border.width: index === root.selected ? 2 : 0
                        border.color: root.accentFor(modelData)

                        Behavior on border.width {
                            EffectMotion {}
                        }
                        Behavior on color {
                            ColorMotion {}
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.leftMargin: 14
                            anchors.rightMargin: 30
                            anchors.topMargin: 12
                            text: modelData.charAt(0).toUpperCase() + modelData.slice(1).replace(/-/g, " ")
                            color: Palette.Theme.textPrimary
                            font.family: Palette.Theme.fontSans
                            font.pixelSize: Palette.Theme.fontSizeSmall
                            font.weight: index === root.selected ? Font.DemiBold : Font.Medium
                            elide: Text.ElideRight
                        }

                        // The theme's palette as one segmented strip.
                        Row {
                            id: strip
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            anchors.bottomMargin: 13
                            height: 8
                            spacing: 2

                            readonly property var colors: root.swatchesFor(card.modelData)

                            Repeater {
                                model: strip.colors
                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index
                                    width: (strip.width - strip.spacing * (strip.colors.length - 1)) / Math.max(1, strip.colors.length)
                                    height: strip.height
                                    topLeftRadius: index === 0 ? height / 2 : 2
                                    bottomLeftRadius: topLeftRadius
                                    topRightRadius: index === strip.colors.length - 1 ? height / 2 : 2
                                    bottomRightRadius: topRightRadius
                                    color: modelData
                                }
                            }
                        }

                        Rectangle {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 8
                            width: 18
                            height: 18
                            radius: 9
                            visible: card.isActive
                            color: root.accentFor(card.modelData)

                            Text {
                                anchors.centerIn: parent
                                text: "✓"
                                color: card.pal && card.pal.onAccent ? card.pal.onAccent : Palette.Theme.accentText
                                font.pixelSize: Palette.Theme.fontSizeXs
                                font.bold: true
                            }
                        }

                        MouseArea {
                            id: cardMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: root.selected = index
                            onClicked: root.apply(index)
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
    Keys.onPressed: function (event) {
        root.handleKey(event);
    }
}
