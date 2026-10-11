#!/usr/bin/env bash
# Apply (or clear) a Hyprland screen shader from ~/.config/hypr/shaders.
set -uo pipefail

shader_name=${1:?usage: apply-shader.sh SHADER_NAME|none}
shaders_dir="$HOME/.config/hypr/shaders"

# Shader names are supplied by Quickshell, but validate again before touching
# any configuration files.
case "$shader_name" in
    ""|*/*|.*) exit 2 ;;
esac

if [ "$shader_name" = "none" ]; then
    shader_path=""
    printf 'return ""\n' > "$HOME/.config/hypr/shader.lua"
else
    shader_path="$shaders_dir/$shader_name.glsl"
    [ -f "$shader_path" ] || exit 2
    # $HOME is resolved by Hyprland, so the tracked file works for any user.
    printf 'return os.getenv("HOME") .. "/.config/hypr/shaders/%s.glsl"\n' "$shader_name" > "$HOME/.config/hypr/shader.lua"
fi

# This config uses Hyprland's Lua parser (hl.config), which rejects the
# legacy `hyprctl keyword` path ("keyword can't work with non-legacy
# parsers"); live updates have to go through `hyprctl eval` instead. Escape
# backslashes/quotes so the path survives as a Lua string literal.
lua_escaped=$(printf '%s' "$shader_path" | sed 's/\\/\\\\/g; s/"/\\"/g')
hyprctl eval "hl.config({decoration={screen_shader=\"$lua_escaped\"}})" >/dev/null

notify-send "Shader" "${shader_name}"
