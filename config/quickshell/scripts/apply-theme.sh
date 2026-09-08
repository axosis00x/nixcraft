#!/usr/bin/env bash
# Apply one of ~/.config/themes/* without relying on a launcher frontend.
set -uo pipefail

theme_name=${1:?usage: apply-theme.sh THEME [WALLPAPER]}
wallpaper_override=${2:-}
themes_dir="$HOME/.config/themes"
theme_dir="$themes_dir/$theme_name"

# Theme names are supplied by Quickshell, but validate again before touching
# any configuration files.
case "$theme_name" in
"" | */* | .*) exit 2 ;;
esac

wallpaper_base="$HOME/Pictures/wallpapers"
if [ -n "$wallpaper_override" ] && [ -f "$wallpaper_override" ]; then
    wallpaper="$wallpaper_override"
else
    wallpaper=$(find "$wallpaper_base/$theme_name" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) 2>/dev/null | shuf -n 1 || true)
fi

# Kick the wallpaper swap off immediately in the background: it's independent
# of everything below (palette regen, hyprctl reload, ...) and its own
# transition takes a while, so waiting on it serially before doing anything
# else only adds dead time to every theme switch.
[ -z "$wallpaper" ] || (awww img "$wallpaper" --transition-type any --transition-duration 0.7 --transition-fps 60 || true) &

# The dynamic theme has no static files of its own: regenerate its whole
# palette using Material Design 3 (matugen) from the wallpaper we just picked.
# matugen's own color extraction cost scales with the source image's pixel
# count (no internal downsampling), so a multi-megapixel wallpaper can take
# over a second; shrinking it first with vipsthumbnail keeps every wallpaper
# on the same fast path regardless of its original resolution.
if [ "$theme_name" = "dynamic" ] && [ -n "$wallpaper" ]; then
    matugen_thumb=$(mktemp --suffix=.png)
    trap 'rm -f "$matugen_thumb"' EXIT
    if vipsthumbnail "$wallpaper" --size 256 -o "$matugen_thumb" 2>/dev/null; then
        matugen_source="$matugen_thumb"
    else
        matugen_source="$wallpaper"
    fi
    matugen --source-color-index 0 image "$matugen_source" \
        --config "$HOME/nixcraft/config/matugen/config.toml" \
        --type scheme-vibrant --mode dark -q || true
fi

[ -d "$theme_dir" ] && [ -f "$theme_dir/hyprland.lua" ] && [ -f "$theme_dir/kitty.conf" ] || exit 2

# Apply Kitty first. The remaining integrations are optional, so a failure in
# one of them must never prevent the terminal theme from changing.
printf 'include %s\n' "$theme_dir/kitty.conf" >"$HOME/.config/kitty/theme.conf"
pkill -USR1 -x kitty 2>/dev/null || true

install_if_present() {
    local source=$1 destination=$2
    [ -f "$source" ] || return 0
    mkdir -p "$(dirname "$destination")"
    cp "$source" "$destination"
}

rm -f "$HOME/.config/gtk-3.0/gtk.css" "$HOME/.config/gtk-4.0/gtk.css"
install_if_present "$theme_dir/gtk-3.css" "$HOME/.config/gtk-3.0/gtk.css"
install_if_present "$theme_dir/gtk-4.css" "$HOME/.config/gtk-4.0/gtk.css"
command -v gsettings >/dev/null && gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3-dark || true

install_if_present "$theme_dir/tmux.conf" "$HOME/.config/tmux/theme.conf"
install_if_present "$theme_dir/yazi-flavor.toml" "$HOME/.config/yazi/flavors/nixcraft.yazi/flavor.toml"
printf 'return dofile("%s")\n' "$theme_dir/hyprland.lua" >"$HOME/.config/hypr/theme.lua"

# nvim watches this file (config/nvim/lua/config/autocmds.lua) and live-
# reloads its colorscheme on change, so writing it is enough — no signal
# or restart needed even for an already-open nvim session.
if [ -f "$theme_dir/neovim.lua" ]; then
    nvim_theme=$(sed -n 's/^return "\(.*\)"/\1/p' "$theme_dir/neovim.lua" | head -n1)
    [ -n "$nvim_theme" ] && printf '%s' "$nvim_theme" >"$HOME/.config/nvim/theme_name.txt"
fi

case "$theme_name" in
gruvbox) zed_theme="Gruvbox Dark" ;;
mocha) zed_theme="Catppuccin Mocha" ;;
tokyonight) zed_theme="Aura Dark" ;;
monochrome) zed_theme="Nord Darker" ;;
moonfly) zed_theme="One Dark Pro Max" ;;
ryo) zed_theme="One Dark Pro Max" ;;
dynamic) zed_theme="One Dark Pro Max" ;;
*) zed_theme="" ;;
esac
if [ -n "$zed_theme" ] && [ -f "$HOME/.config/zed/settings.json" ]; then
    sed -i '/"theme": {/,/}/{
        s/"light": *"[^"]*"/"light": "'"$zed_theme"'"/
        s/"dark": *"[^"]*"/"dark": "'"$zed_theme"'"/
    }' "$HOME/.config/zed/settings.json"
fi

"$HOME/.config/quickshell/scripts/build-theme.sh" || true
hyprctl reload >/dev/null || true
pgrep tmux >/dev/null && tmux source-file "$HOME/.config/tmux/tmux.conf" 2>/dev/null || true
notify-send -i "$wallpaper" "Theme Activated" "Applied $theme_name"
