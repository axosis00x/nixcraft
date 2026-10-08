#!/usr/bin/env bash
# Point helium.nix at the newest Helium release: looks up the latest GitHub
# release, prefetches its x86_64 AppImage, and rewrites `version` and `hash`.
# Then rebuild:  sudo nixos-rebuild switch --flake ~/nixcraft#oneiros
set -euo pipefail

nix_file="$(dirname "$(readlink -f "$0")")/helium.nix"

latest=$(curl -fsSL https://api.github.com/repos/imputnet/helium-linux/releases/latest |
    sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n1)
[ -n "$latest" ] || { echo "Could not read the latest release from GitHub" >&2; exit 1; }

current=$(sed -n 's/^ *version = "\(.*\)";/\1/p' "$nix_file" | head -n1)
if [ "$latest" = "$current" ]; then
    echo "Helium is already at the latest version ($current)."
    exit 0
fi

url="https://github.com/imputnet/helium-linux/releases/download/${latest}/helium-${latest}-x86_64.AppImage"
echo "Updating Helium $current -> $latest"
hash=$(nix store prefetch-file --json "$url" | sed -n 's/.*"hash": *"\([^"]*\)".*/\1/p')
[ -n "$hash" ] || { echo "Could not prefetch $url" >&2; exit 1; }

sed -i -E \
    -e "s|^( *version = )\"[^\"]*\";|\1\"${latest}\";|" \
    -e "s|^( *hash = )\"sha256-[^\"]*\";|\1\"${hash}\";|" \
    "$nix_file"

echo "helium.nix now pins ${latest} (${hash}). Rebuild to install it."
