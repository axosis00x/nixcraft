#!/usr/bin/env bash
# Video wallpapers via mpvpaper (awww handles images and GIFs).
#
#   live-wallpaper.sh thumbs VIDEO...   first-frame previews for the picker
#   live-wallpaper.sh video VIDEO       play VIDEO on every monitor
#   live-wallpaper.sh stop              back to awww
#   live-wallpaper.sh restore           replay the last video (login)
#   live-wallpaper.sh current           print the playing video, if any
#
# Thumbnails are named by the md5 of the video's path, which the wallpaper
# picker recomputes with Qt.md5() to find them.
set -uo pipefail

cache="$HOME/.cache/quickshell/wallpicker"
state="$cache/video"
mkdir -p "$cache"

key() { printf '%s' "$1" | md5sum | cut -c1-32; }

play() {
    pkill -f '^[^ ]*/mpvpaper '
    # -p pauses playback while windows cover the wallpaper.
    setsid -f mpvpaper -p -o "no-audio loop hwdec=auto panscan=1.0" '*' "$1" >/dev/null 2>&1
}

case ${1:-} in
thumbs)
    shift
    for video in "$@"; do
        thumb="$cache/$(key "$video").jpg"
        [ -s "$thumb" ] && continue
        ffmpeg -nostdin -loglevel error -y -ss 1 -i "$video" -frames:v 1 -vf "scale=512:-2" "$thumb" ||
            ffmpeg -nostdin -loglevel error -y -i "$video" -frames:v 1 -vf "scale=512:-2" "$thumb"
    done
    ;;
video)
    video=${2:?usage: live-wallpaper.sh video VIDEO}
    [ -f "$video" ] || exit 2
    printf '%s\n' "$video" >"$state"
    play "$video"
    ;;
stop)
    command rm -f "$state"
    pkill -f '^[^ ]*/mpvpaper '
    ;;
restore)
    [ -s "$state" ] && [ -f "$(cat "$state")" ] && play "$(cat "$state")"
    ;;
current)
    [ -s "$state" ] && cat "$state"
    ;;
*)
    exit 2
    ;;
esac
exit 0
