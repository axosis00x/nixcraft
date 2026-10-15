-- ┌─┐┬ ┬┌┬┐┌─┐┌─┐┌┬┐┌─┐┬─┐┌┬┐
-- ├─┤│ │ │ │ │└─┐ │ ├─┤├┬┘ │
-- ┴ ┴└─┘ ┴ └─┘└─┘ ┴ ┴ ┴┴└─ ┴

hl.on("hyprland.start", function()
    hl.exec_cmd("awww-daemon &")
    hl.exec_cmd("nm-applet &")
    hl.exec_cmd("hyprsunset --temperature 4500 --gamma 90")
    -- Basic (main-thread) render loop: Qt's threaded loop crashes in Intel's
    -- iris Mesa driver (iris_fence_flush) when album art changes.
    hl.exec_cmd("QSG_RENDER_LOOP=basic qs & disown")
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("wl-paste --watch cliphist store &")
    -- Clipboard sharing with the host when this is a VM (settings.vm).
    -- spice-vdagent is X11-only, so it runs through XWayland; it has to start
    -- inside the session or spice-vdagentd rejects it. Only installed on VMs.
    hl.exec_cmd("command -v spice-vdagent >/dev/null && spice-vdagent -x")
    hl.exec_cmd("hyprctl setcursor Mocu-Black-Right 24")
end)
