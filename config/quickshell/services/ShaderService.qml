import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: root
    visible: false

    // "none" (no screen shader) is always first.
    property var shaders: ["none"]
    property string activeShader: "none"
    property bool isPreviewing: false
    property string pendingPreview: ""
    property string originalShader: ""

    Component.onCompleted: refresh()

    function refresh() {
        shaderList.running = true;
        activeShaderRead.running = true;
    }

    function preview(shaderName) {
        if (!shaders || (shaders.indexOf(shaderName) === -1 && shaderName !== "none"))
            return;
        if (!isPreviewing) {
            originalShader = activeShader;
            isPreviewing = true;
        }
        pendingPreview = shaderName;
        previewDebounce.restart();
    }

    function cancelPreview() {
        previewDebounce.stop();
        pendingPreview = "";
        if (isPreviewing) {
            isPreviewing = false;
            var target = originalShader !== "" ? originalShader : activeShader;
            executeWithProcess(restoreProcess, target);
            originalShader = "";
        }
    }

    function apply(shaderName) {
        previewDebounce.stop();
        pendingPreview = "";
        isPreviewing = false;
        originalShader = "";
        if (shaders.indexOf(shaderName) === -1)
            return;
        activeShader = shaderName;
        applyShader.exec([Quickshell.env("HOME") + "/.config/quickshell/scripts/apply-shader.sh", shaderName]);
    }

    function executeWithProcess(proc, shaderName) {
        var shaderPath = "";
        if (shaderName && shaderName !== "none") {
            shaderPath = Quickshell.env("HOME") + "/.config/hypr/shaders/" + shaderName + ".glsl";
        }
        var luaEscaped = shaderPath.replace(/\\/g, "\\\\").replace(/"/g, '\\"');
        proc.exec(["hyprctl", "eval", "hl.config({decoration={screen_shader=\"" + luaEscaped + "\"}})"]);
    }

    function executeShader(shaderName) {
        executeWithProcess(previewProcess, shaderName);
    }

    Timer {
        id: previewDebounce
        interval: 35
        onTriggered: {
            if (root.pendingPreview !== "") {
                root.executeShader(root.pendingPreview);
            }
        }
    }

    Process {
        id: previewProcess
    }

    Process {
        id: restoreProcess
    }

    // Filenames are the stable shader IDs (used by apply-shader.sh and
    // decoration:screen_shader), so this is just a display-only prettifier.
    function displayName(shaderName) {
        if (typeof shaderName !== "string")
            return "";
        if (shaderName === "none")
            return "None";
        return shaderName.split("_").map(word => word.charAt(0).toUpperCase() + word.slice(1)).join(" ");
    }

    Process {
        id: shaderList
        command: ["sh", "-c", "printf 'none\\n'; for f in \"$HOME/.config/hypr/shaders\"/*.glsl; do [ -f \"$f\" ] || continue; b=\"${f##*/}\"; printf '%s\\n' \"${b%.glsl}\"; done | sort"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.shaders = text.trim() === "" ? ["none"] : text.trim().split("\n");
            }
        }
    }

    Process {
        id: activeShaderRead
        command: ["sh", "-c", "grep -o '[^/\"]*\\.glsl' \"$HOME/.config/hypr/shader.lua\" 2>/dev/null | head -n 1 | sed 's/\\.glsl$//'"]
        stdout: StdioCollector {
            onStreamFinished: {
                var name = text.trim();
                var resolved = name === "" ? "none" : name;
                if (!root.isPreviewing) {
                    root.activeShader = resolved;
                } else {
                    root.originalShader = resolved;
                }
            }
        }
    }

    Process {
        id: applyShader
    }
}
