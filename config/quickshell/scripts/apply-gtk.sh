#!/usr/bin/env bash
# Push a theme's GTK colors into every running GTK app, not just new ones.
#
# GTK reads ~/.config/gtk-3.0/gtk.css once per process, so rewriting it never
# reaches apps that are already open — notably xdg-desktop-portal-gtk, whose
# file chooser lives for the whole session. Named themes *are* reloaded live
# whenever org.gnome.desktop.interface gtk-theme changes, so the colors are
# baked into a generated theme instead, alternating between two slot names so
# the setting always genuinely changes and triggers that reload.
set -uo pipefail

theme_dir=${1:?usage: apply-gtk.sh THEME_DIR}

base=""
for candidate in \
    "/etc/profiles/per-user/$USER/share/themes/adw-gtk3-dark" \
    "$HOME/.nix-profile/share/themes/adw-gtk3-dark" \
    "/run/current-system/sw/share/themes/adw-gtk3-dark"; do
    if [ -f "$candidate/gtk-3.0/gtk.css" ]; then
        base=$candidate
        break
    fi
done
[ -n "$base" ] || exit 1

themes_root="${XDG_DATA_HOME:-$HOME/.local/share}/themes"

if [ "$(dconf read /org/gnome/desktop/interface/gtk-theme 2>/dev/null)" = "'nixcraft-a'" ]; then
    slot=nixcraft-b
else
    slot=nixcraft-a
fi

# The theme files only define the core palette; everything else would fall
# back to stock Adwaita grays (dialogs, the file chooser's places sidebar,
# thumbnails, unfocused headerbars). Derive those from the core palette so
# they follow the theme too. Emitted before the theme's own colors, so a
# theme that does define one of these still wins.
derived='@define-color dialog_bg_color @popover_bg_color;
@define-color dialog_fg_color @popover_fg_color;
@define-color headerbar_backdrop_color @headerbar_bg_color;
@define-color secondary_sidebar_bg_color @sidebar_bg_color;
@define-color secondary_sidebar_fg_color @sidebar_fg_color;
@define-color secondary_sidebar_backdrop_color @sidebar_backdrop_color;
@define-color secondary_sidebar_border_color @sidebar_border_color;
@define-color thumbnail_bg_color @card_bg_color;
@define-color thumbnail_fg_color @card_fg_color;'

write_atomic() {
    local dest=$1
    mkdir -p "$(dirname "$dest")"
    cat >"$dest.tmp" && mv "$dest.tmp" "$dest"
}

for ver in 3 4; do
    colors="$theme_dir/gtk-$ver.css"
    [ -f "$colors" ] || continue
    {
        printf '@import url("file://%s/gtk-%s.0/gtk.css");\n' "$base" "$ver"
        printf '%s\n' "$derived"
        cat "$colors"
    } | write_atomic "$themes_root/$slot/gtk-$ver.0/gtk.css"
done

# libadwaita ignores gtk-theme entirely and only reads the user stylesheet,
# so GTK4 still needs it (already-open libadwaita apps can't be refreshed).
if [ -f "$theme_dir/gtk-4.css" ]; then
    { printf '%s\n' "$derived"; cat "$theme_dir/gtk-4.css"; } | write_atomic "$HOME/.config/gtk-4.0/gtk.css"
fi

# GTK3 gets its colors from the theme now. A user stylesheet would sit on
# top of it at higher priority and, being loaded once, pin every running
# GTK3 app to whatever colors were current when it started.
rm -f "$HOME/.config/gtk-3.0/gtk.css"

dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'"
dconf write /org/gnome/desktop/interface/gtk-theme "'$slot'"
