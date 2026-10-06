#!/usr/bin/env bash
# Emit a theme's quickshell.js palette as key<TAB>value rows, read by
# services/ThemeService.qml to apply (or preview) a palette live through
# theme/Theme.qml.
#   build-theme.sh rows THEME
set -uo pipefail

[ "${1:-}" = "rows" ] || { echo "usage: build-theme.sh rows THEME" >&2; exit 2; }
theme_name=${2:?usage: build-theme.sh rows THEME}
case "$theme_name" in ""|*/*|.*) exit 2 ;; esac

source_file="$HOME/.config/themes/$theme_name/quickshell.js"
[ -f "$source_file" ] || exit 2

sed -n 's/^const \([A-Za-z][A-Za-z0-9]*\) = "\(.*\)"$/\1\t\2/p' "$source_file"
