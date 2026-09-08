import Quickshell
import Quickshell.Io
import QtQuick
import "../theme" as Palette

Item {
    id: root
    visible: false

    property var themes: []
    property string activeTheme: ""
    signal applied(string themeName)

    Component.onCompleted: refresh()

    function refresh() {
        themeList.running = true;
    }

    function apply(themeName, wallpaperPath) {
        if (themes.indexOf(themeName) === -1)
            return;
        pendingTheme = themeName;
        // Quickshell owns this singleton, so repaint it first with whatever
        // palette is on disk. For static themes that's already correct; the
        // "dynamic" theme rewrites its palette from the wallpaper on every
        // apply, so it gets a second, authoritative read once the script
        // below (and wallust within it) has actually finished.
        activeTheme = themeName;
        readPalette(themeName);
        applied(themeName);
        var cmd = [Quickshell.env("HOME") + "/.config/quickshell/scripts/apply-theme.sh", themeName];
        if (wallpaperPath)
            cmd.push(wallpaperPath);
        applyTheme.exec(cmd);
    }

    property string pendingTheme: ""

    function readPalette(themeName) {
        if (themeName !== "")
            paletteRead.exec([Quickshell.env("HOME") + "/.config/quickshell/scripts/build-theme.sh", "rows", themeName]);
    }

    Process {
        id: themeList
        command: ["sh", "-c", "for d in \"$HOME\"/.config/themes/*/; do [ -d \"$d\" ] || continue; d=\"${d%/}\"; printf '%s\\n' \"${d##*/}\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.themes = text.trim() === "" ? [] : text.trim().split("\n");
                activeThemeRead.running = true;
            }
        }
    }

    Process {
        id: activeThemeRead
        command: ["sh", "-c", "sed -n 's/.*dofile(\"\\(.*\\)\").*/\\1/p' \"$HOME/.config/hypr/theme.lua\" | head -n 1 | xargs -r dirname | xargs -r basename"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.activeTheme = text.trim();
                root.readPalette(root.activeTheme);
            }
        }
    }

    Process {
        id: paletteRead
        stdout: StdioCollector {
            onStreamFinished: {
                var values = {};
                var rows = text.trim() === "" ? [] : text.trim().split("\n");
                for (var i = 0; i < rows.length; i++) {
                    var tab = rows[i].indexOf("\t");
                    if (tab > 0) {
                        var key = rows[i].slice(0, tab);
                        if (key === "error")
                            key = "errorColor";
                        if (key === "onAccent")
                            key = "accentText";
                        if (key === "onPrimaryContainer")
                            key = "primaryText";
                        if (key === "onSecondaryContainer")
                            key = "secondaryText";
                        values[key] = rows[i].slice(tab + 1);
                    }
                }
                Palette.Theme.apply(values);
            }
        }
    }

    Process {
        id: applyTheme
        onExited: function (exitCode, exitStatus) {
            if (exitCode === 0 && root.pendingTheme !== "") {
                root.activeTheme = root.pendingTheme;
                // Re-read now that the script (and, for "dynamic", wallust)
                // has finished writing the palette this apply used.
                root.readPalette(root.activeTheme);
            }
            root.pendingTheme = "";
        }
    }
}
