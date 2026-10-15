#!/usr/bin/env bash
# Fully restart the shell (needed after editing the polkit agent, which a
# reload doesn't re-register). Quickshell 0.3.2 can segfault while quitting,
# and its crash handler then starts the shell again by itself; only start
# one here if that didn't happen, so there are never two shells running.

old=$(qs list 2>/dev/null | awk '/Process ID:/ {print $3}')
qs kill >/dev/null 2>&1

# Wait for the old instance to be gone...
for pid in $old; do
    for _ in $(seq 20); do
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.25
    done
done

# ...then give a crash-handler restart a moment to appear.
for _ in $(seq 8); do
    qs list 2>/dev/null | grep -q "^Instance" && exit 0
    sleep 0.25
done

# Same render loop as the Hyprland autostart (see hypr/modules/autostarts.lua).
QSG_RENDER_LOOP=basic setsid qs >/dev/null 2>&1 &
disown
