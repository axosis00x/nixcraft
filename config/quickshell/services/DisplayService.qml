import Quickshell
import Quickshell.Io
import QtQuick

// Resolution, scale and mirroring for each connected output. Live state comes
// from `hyprctl monitors all`; a change rewrites ~/.config/hypr/displays.lua
// (read by hypr/modules/monitors.lua) from that state plus the change, then
// reloads Hyprland. Every change is provisional: unless confirmed with
// keep() it reverts after `confirmSeconds`, so a mode the screen can't show
// undoes itself. The pre-change file is kept on disk (displays.lua.revert),
// so a shell restart mid-countdown also counts as "not confirmed".
Item {
    id: root
    visible: false

    property var monitors: []
    // Output the built-in panel mirrors, or "" when extending.
    property string mirrorSource: "HDMI-A-1"
    readonly property bool mirror: mirrorSource !== ""

    readonly property var builtIn: monitors.find(m => isBuiltIn(m.name)) || null
    readonly property var external: monitors.find(m => !isBuiltIn(m.name)) || null

    readonly property int confirmSeconds: 15
    property int secondsLeft: 0
    readonly property bool pending: secondsLeft > 0

    readonly property string path: Quickshell.env("HOME") + "/.config/hypr/displays.lua"
    readonly property string backup: path + ".revert"

    // A backup left behind means a change was never confirmed.
    Component.onCompleted: run("[ -f \"$2\" ] && mv \"$2\" \"$1\" && hyprctl reload >/dev/null; true")

    function isBuiltIn(name) {
        return /^(eDP|LVDS|DSI)/.test(name);
    }

    function refresh() {
        monitorsRead.running = true;
        fileRead.running = true;
    }

    // "1366x768@60.02Hz" -> "1366x768@60.02"
    function modeId(mode) {
        return mode.replace(/Hz$/, "");
    }

    function currentMode(m) {
        return m.width + "x" + m.height + "@" + m.refreshRate.toFixed(2);
    }

    // Available modes, one per resolution (its highest refresh rate),
    // largest first.
    function modesFor(m) {
        var best = {};
        (m.availableModes || []).forEach(raw => {
            var id = modeId(raw);
            var parts = id.split("@");
            var res = parts[0];
            var hz = parseFloat(parts[1]);
            if (!best[res] || hz > best[res].hz)
                best[res] = { id: id, res: res, hz: hz };
        });
        var list = Object.keys(best).map(k => best[k]);
        list.sort((a, b) => {
            var pa = a.res.split("x"), pb = b.res.split("x");
            return pb[0] * pb[1] - pa[0] * pa[1];
        });
        return list;
    }

    // Scales Hyprland will accept for this output: it needs both sides of
    // the resolution to divide into whole logical pixels, at a multiple of
    // 1/120. For each common step, the nearest valid value (if any close).
    function scalesFor(m) {
        var out = [];
        [1, 1.25, 1.5, 1.75, 2].forEach(target => {
            var found = 0;
            for (var d = 0; d <= 12 && !found; d++) {
                [target - d / 120, target + d / 120].forEach(s => {
                    var w = m.width / s, h = m.height / s;
                    if (!found && s >= 1 && Math.abs(w - Math.round(w)) < 0.001 && Math.abs(h - Math.round(h)) < 0.001)
                        found = Math.round(s * 120) / 120;
                });
            }
            if (found && out.indexOf(found) === -1)
                out.push(found);
        });
        return out;
    }

    // Matches the current mode against the list by resolution, since the
    // reported refresh rate is rounded differently from the mode list.
    function isCurrentMode(m, mode) {
        return mode.res === m.width + "x" + m.height;
    }

    function setMode(name, mode) {
        apply(name, { mode: mode });
    }

    function setScale(name, scale) {
        apply(name, { scale: scale });
    }

    function setMirror(on) {
        var source = on ? (external ? external.name : (mirrorSource || "HDMI-A-1")) : "";
        apply("", {}, source);
    }

    function render(override, outputName, source) {
        var lines = ["-- Written by the Quickshell settings panel (Display page); read by", "-- modules/monitors.lua.", "return {", "    mirror = " + (source ? "\"" + source + "\"" : "false") + ",", "    outputs = {"];
        monitors.forEach(m => {
            var mode = currentMode(m);
            var scale = m.scale;
            if (m.name === outputName) {
                if (override.mode)
                    mode = override.mode;
                if (override.scale)
                    scale = override.scale;
            }
            lines.push("        [\"" + m.name + "\"] = { mode = \"" + mode + "\", scale = " + Number(scale).toFixed(4) + " },");
        });
        lines.push("    },", "}", "");
        return lines.join("\n");
    }

    function apply(outputName, override, source) {
        if (source === undefined)
            source = mirrorSource;
        mirrorSource = source;
        // cp -n keeps the first snapshot if changes stack up before
        // confirming, so a revert goes all the way back.
        run("[ -f \"$1\" ] && cp -n \"$1\" \"$2\"; printf '%s' \"$3\" > \"$1\" && hyprctl reload >/dev/null", render(override, outputName, source));
        secondsLeft = confirmSeconds;
        countdown.restart();
    }

    function keep() {
        countdown.stop();
        secondsLeft = 0;
        run("rm -f \"$2\"");
    }

    function revert() {
        countdown.stop();
        secondsLeft = 0;
        run("[ -f \"$2\" ] && mv \"$2\" \"$1\" && hyprctl reload >/dev/null; true");
    }

    // $1 = displays.lua, $2 = its backup, $3 = optional new contents.
    function run(script, text) {
        writer.exec(["sh", "-c", script, "sh", path, backup, text || ""]);
    }

    Timer {
        id: countdown
        interval: 1000
        repeat: true
        onTriggered: {
            root.secondsLeft -= 1;
            if (root.secondsLeft <= 0)
                root.revert();
        }
    }

    Process {
        id: writer
        // Give Hyprland a moment to re-apply modes before reading them back.
        onExited: settle.restart()
    }

    Timer {
        id: settle
        interval: 600
        onTriggered: root.refresh()
    }

    Process {
        id: monitorsRead
        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.monitors = JSON.parse(text);
                } catch (e) {
                    root.monitors = [];
                }
            }
        }
    }

    Process {
        id: fileRead
        command: ["cat", root.path]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text === "")
                    return;
                var m = text.match(/mirror\s*=\s*"([^"]*)"/);
                root.mirrorSource = m ? m[1] : (/mirror\s*=\s*false/.test(text) ? "" : "HDMI-A-1");
            }
        }
    }
}
