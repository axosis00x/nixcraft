#!/usr/bin/env bash
# Prints "theme<TAB>key<TAB>#hex" for the palette colors the theme picker
# previews: the UI colors from each theme's quickshell.js, plus its terminal
# colors (ansi1..ansi6 from kitty.conf) to top up themes whose UI palette
# repeats a color.
for dir in "$HOME"/.config/themes/*/; do
    dir=${dir%/}
    theme=${dir##*/}
    if [ -f "$dir/quickshell.js" ]; then
        sed -n -E 's/^const (bg|surfaceContainerHigh|border|textPrimary|accent|info|success|warning|error) = "([^"]*)".*/\1\t\2/p' "$dir/quickshell.js" |
            awk -F'\t' -v t="$theme" '{ print t "\t" $1 "\t" $2 }'
    fi
    if [ -f "$dir/kitty.conf" ]; then
        sed -n -E 's/^color([1-6])[[:space:]]+(#[0-9a-fA-F]{6}).*/ansi\1\t\2/p' "$dir/kitty.conf" |
            awk -F'\t' -v t="$theme" '{ print t "\t" $1 "\t" $2 }'
    fi
done
