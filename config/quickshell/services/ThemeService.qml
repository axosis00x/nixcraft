import Quickshell
import Quickshell.Io
import QtQuick
import "../theme" as Palette

Item {
    id: root
    visible: false

    property var themes: []
    // theme name -> { bg, surfaceContainerHigh, border, textPrimary, accent, info, success, warning, error }
    property var palettes: ({})
    property string activeTheme: ""
    // Path of the wallpaper on screen, as awww last cached it.
    property string currentWallpaper: ""
    signal applied(string themeName)

    Component.onCompleted: refresh()

    function refresh() {
        themeList.running = true;
        readSwatches();
        refreshWallpaper();
    }

    function refreshWallpaper() {
        wallpaperRead.running = true;
    }

    function setWallpaper(path) {
        currentWallpaper = path;
        // The dynamic theme's whole palette is derived from its wallpaper,
        // so picking a new one has to go through wallust (via apply-theme.sh)
        // rather than just swapping the image.
        if (activeTheme === "dynamic") {
            apply("dynamic", path);
            return;
        }
        setWallpaperProcess.exec(["awww", "img", path, "--transition-type", "any", "--transition-duration", "0.7", "--transition-fps", "60"]);
    }

    // Five distinct colors to preview a theme by: its UI accents first, then
    // its terminal colors to fill in wherever the UI palette repeats itself.
    function swatchesFor(themeName) {
        var pal = palettes[themeName];
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

    Process {
        id: setWallpaperProcess
    }

    Process {
        id: wallpaperRead
        command: ["sh", "-c", "find ~/.cache/awww -type f 2>/dev/null | head -1 | xargs cat 2>/dev/null | tr '\\0' '\\n' | grep '^/' | tail -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                var path = text.trim();
                if (path.length > 0)
                    root.currentWallpaper = path;
            }
        }
    }

    function readSwatches() {
        swatchRead.exec(["bash", Quickshell.env("HOME") + "/.config/quickshell/scripts/theme-swatches.sh"]);
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
        id: swatchRead
        stdout: StdioCollector {
            onStreamFinished: {
                var out = {};
                text.trim().split("\n").forEach(line => {
                    var parts = line.split("\t");
                    if (parts.length !== 3)
                        return;
                    (out[parts[0]] = out[parts[0]] || {})[parts[1]] = parts[2];
                });
                root.palettes = out;
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
                // The dynamic theme's colors were just rewritten.
                root.readSwatches();
                // A theme switch also swaps the wallpaper.
                root.refreshWallpaper();
            }
            root.pendingTheme = "";
        }
    }
}
