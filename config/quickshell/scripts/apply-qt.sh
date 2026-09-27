#!/usr/bin/env bash
# Point qt5ct/qt6ct (Qt5 and Qt6 apps) at a theme's color scheme: stock Fusion
# style with just the palette overridden.
#
# Both plugins watch their config directory and re-read everything a few
# seconds after it changes. Replacing qt{5,6}ct.conf by rename (rather than
# rewriting it in place) is what registers as a directory change, so already
# open Qt apps repaint too, not just newly launched ones.
set -uo pipefail

theme_dir=${1:?usage: apply-qt.sh THEME_DIR}
[ -f "$theme_dir/qt.conf" ] || exit 0

for ct in qt5ct qt6ct; do
    dir="$HOME/.config/$ct"
    mkdir -p "$dir/colors"

    cp "$theme_dir/qt.conf" "$dir/colors/nixcraft.conf.tmp"
    mv "$dir/colors/nixcraft.conf.tmp" "$dir/colors/nixcraft.conf"

    cat >"$dir/$ct.conf.tmp" <<EOF
[Appearance]
color_scheme_path=$dir/colors/nixcraft.conf
custom_palette=true
standard_dialogs=default
style=Fusion
EOF
    mv "$dir/$ct.conf.tmp" "$dir/$ct.conf"
done
