#!/usr/bin/env bash

hyprctl reload

if qs list 2>/dev/null | grep -q .; then
    qs ipc call shell reload
else
    # Same render loop as the Hyprland autostart: Qt's threaded loop crashes
    # in Intel's iris Mesa driver (see hypr/modules/autostarts.lua).
    QSG_RENDER_LOOP=basic qs &
    disown
fi
