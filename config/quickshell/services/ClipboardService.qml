import Quickshell
import Quickshell.Io
import QtQuick

Item {
    id: root
    visible: false

    property var entries: []

    // ── pins ─────────────────────────────────────────────────────────
    // A pinned item's full content (text or image bytes) is saved to its
    // own file, so it survives cliphist ageing it out or a wipe. The JSON
    // index keeps only the one-line preview cliphist showed for it.
    readonly property string pinDir: Quickshell.cachePath("clipboard-pins")
    readonly property var pins: pinIndex.items

    function pinPath(pid) {
        return pinDir + "/" + pid;
    }

    function isPinned(text) {
        return pins.some(p => p.text === text);
    }

    function pin(entry) {
        if (!entry || !/^[0-9]+$/.test(entry.id) || isPinned(entry.text))
            return;
        var pid = String(Date.now());
        pinIndex.items = [{
                pid: pid,
                text: entry.text
            }].concat(pins);
        pinProc.exec(["sh", "-c", "mkdir -p \"$(dirname \"$2\")\" && cliphist decode \"$1\" > \"$2\"", "cliphist-pin", entry.id, pinPath(pid)]);
    }

    function unpin(pid) {
        pinIndex.items = pins.filter(p => p.pid !== pid);
        pinProc.exec(["rm", "-f", pinPath(pid)]);
    }

    function copyPin(pid) {
        if (!/^[0-9]+$/.test(pid))
            return;
        decode.exec(["sh", "-c", "wl-copy < \"$1\"", "clipboard-pin", pinPath(pid)]);
    }

    FileView {
        path: Quickshell.cachePath("clipboard-pins.json")
        watchChanges: false
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: pinIndex
            property var items: []
        }
    }

    Process {
        id: pinProc
    }

    function refresh() {
        history.running = true;
    }

    function copy(entryId) {
        if (!/^[0-9]+$/.test(entryId))
            return;
        decode.exec(["sh", "-c", "cliphist decode \"$1\" | wl-copy", "cliphist-decode", entryId]);
    }

    // Removes one entry; cliphist delete takes the exact list line on stdin.
    function remove(entryId) {
        if (!/^[0-9]+$/.test(entryId))
            return;
        entries = entries.filter(e => e.id !== entryId);
        removeProc.exec(["sh", "-c", "cliphist list | grep -m1 \"^$1\t\" | cliphist delete", "cliphist-delete", entryId]);
    }

    // Image entries are decoded once into the cache so the panel can show
    // a thumbnail; returns the file path to load.
    readonly property string previewDir: Quickshell.cachePath("clipboard-previews")

    function previewPath(entryId) {
        return previewDir + "/" + entryId;
    }

    function decodePreviews(list) {
        var ids = list.filter(e => /^\[\[\s*binary data.*(png|jpe?g|webp|gif|bmp)/i.test(e.text)).map(e => e.id);
        if (ids.length === 0)
            return;
        previewProc.exec(["sh", "-c", "d=\"$1\"; shift; mkdir -p \"$d\"; for id in \"$@\"; do [ -s \"$d/$id\" ] || cliphist decode \"$id\" > \"$d/$id\"; done", "cliphist-preview", previewDir].concat(ids));
    }

    function clear() {
        entries = [];
        wipe.running = true;
    }

    Process {
        id: history
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                var rows = text.trim() === "" ? [] : text.trim().split("\n");
                var parsed = [];
                // cliphist already emits newest entries first. Keep that order
                // so the top row is always the latest copied item.
                for (var i = 0; i < rows.length && parsed.length < 50; ++i) {
                    var tab = rows[i].indexOf("\t");
                    if (tab > 0)
                        parsed.push({
                            id: rows[i].slice(0, tab),
                            text: rows[i].slice(tab + 1)
                        });
                }
                root.entries = parsed;
                root.decodePreviews(parsed);
            }
        }
    }

    Process {
        id: decode
    }
    Process {
        id: removeProc
    }
    // Bumps once previews are on disk so delegates retry their images.
    property int previewsReady: 0
    Process {
        id: previewProc
        onExited: root.previewsReady++
    }
    Process {
        id: wipe
        command: ["sh", "-c", "cliphist wipe; wl-copy --clear; rm -rf \"$1\"", "cliphist-wipe", root.previewDir]
    }
}
