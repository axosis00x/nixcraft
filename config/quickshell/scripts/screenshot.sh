#!/usr/bin/env bash

# r: region
# s: screen (focused monitor)
# w: pick a window

# c: clipboard
# f: file (also copied to the clipboard)
# i: interactive (open in swappy)

dir=~/Pictures/Screenshots
mkdir -p "$dir"

case $1 in
rc) hyprshot -z -m region --clipboard-only ;;
rf) hyprshot -z -m region -o "$dir" ;;
ri) hyprshot -z -m region -r | swappy -f - ;;
sc) hyprshot -m output -m active --clipboard-only ;;
sf) hyprshot -m output -m active -o "$dir" ;;
si) hyprshot -m output -m active -r | swappy -f - ;;
w) hyprshot -z -m window -o "$dir" ;;
esac
