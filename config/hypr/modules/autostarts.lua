-- ┌─┐┬ ┬┌┬┐┌─┐┌─┐┌┬┐┌─┐┬─┐┌┬┐
-- ├─┤│ │ │ │ │└─┐ │ ├─┤├┬┘ │
-- ┴ ┴└─┘ ┴ └─┘└─┘ ┴ ┴ ┴┴└─ ┴

hl.on("hyprland.start", function()
    hl.exec_cmd("awww-daemon & awww img ~/Pictures/wallpapers/night.png")
    hl.exec_cmd("nm-applet &")
    hl.exec_cmd("hyprsunset")
    -- Basic (main-thread) render loop: Qt's threaded loop crashes in Intel's
    -- iris Mesa driver (iris_fence_flush) when album art changes.
    hl.exec_cmd("QSG_RENDER_LOOP=basic qs & disown")
    hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    hl.exec_cmd("wl-paste --watch cliphist store &")
    hl.exec_cmd("hyprctl setcursor Mocu-Black-Right 24")
end)
