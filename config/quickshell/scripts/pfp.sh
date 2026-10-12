#!/usr/bin/env bash
# Profile picture: ~/.face, read by the shell (components/material/Avatar.qml)
# and, through the nixcraft-pfp-sync unit (modules/system/sddm), by the login
# screen. Without one, both show nixcraft's default, assets/pfp.png.
#
#   pfp.sh pick         choose an image in a file dialog, then set it
#   pfp.sh set IMAGE    set IMAGE (cropped to a 512px square)
#   pfp.sh reset        go back to the default
set -euo pipefail

face="$HOME/.face"

set_image() {
    local src=$1 tmp="$HOME/.face.new.png"
    [[ -f $src ]] || {
        echo "No such file: $src" >&2
        exit 1
    }
    # A centred 512px square keeps it small and sharp everywhere it's shown;
    # anything vips can't read is used as-is.
    if ! vips thumbnail "$src" "$tmp" 512 --height 512 --crop centre 2>/dev/null; then
        cp -f "$src" "$tmp"
    fi
    # Replace in one step, so watchers only ever see a whole picture.
    mv -f "$tmp" "$face"
}

case "${1:-}" in
    pick)
        file=$(zenity --file-selection --title="Choose a profile picture" \
            --filename="$HOME/Pictures/" \
            --file-filter="Images | *.png *.jpg *.jpeg *.webp *.gif *.bmp *.PNG *.JPG *.JPEG *.WEBP" \
            2>/dev/null) || exit 0 # cancelled
        set_image "$file"
        ;;
    set)
        set_image "${2:?usage: pfp.sh set IMAGE}"
        ;;
    reset)
        rm -f "$face"
        ;;
    *)
        sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
        exit 2
        ;;
esac
