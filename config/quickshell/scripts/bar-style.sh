#!/usr/bin/env bash
# Point Hyprland's workspace-switch animation at the direction matching the
# bar's current edge (see hypr/modules/animations.lua, vertAni.lua,
# horizAni.lua) and reload to pick it up. Called by BarLayoutService.qml
# whenever the bar layout picker changes orientation.
set -uo pipefail

orientation=${1:?usage: bar-style.sh vertical|horizontal}

case "$orientation" in
    vertical|horizontal) ;;
    *) exit 2 ;;
esac

printf 'return "%s"\n' "$orientation" > "$HOME/.config/hypr/barorientation.lua"
hyprctl reload >/dev/null || true
