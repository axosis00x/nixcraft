#!/usr/bin/env bash
# One-line nixcraft install for a fresh NixOS system:
#
#   curl -fsSL https://subashlamatamang.com.np/install | bash
#   curl -fsSL https://subashlamatamang.com.np/install | bash -s -- --demo   # look, don't touch
#
# Clones the repo to ~/nixcraft (or reuses it) and runs ./install.sh, passing
# any arguments through. Everything is inside main(), so a download cut off
# halfway never runs a partial script.
set -euo pipefail

main() {
    local repo_url=${NIXCRAFT_REPO:-https://github.com/axosis00x/nixcraft}
    local dest=${NIXCRAFT_DIR:-$HOME/nixcraft}

    if [[ $EUID -eq 0 ]]; then
        echo "Run this as your normal user, not root (it uses sudo where needed)." >&2
        exit 1
    fi
    if [[ ! -e /etc/NIXOS ]]; then
        echo "This installs a NixOS configuration; run it on NixOS." >&2
        exit 1
    fi

    # git and lspci aren't on a fresh install; borrow them from nixpkgs.
    local shell=(nix-shell -p git pciutils --run)

    if [[ -d $dest/.git ]]; then
        echo "==> Using the existing checkout at $dest (update it with: git -C $dest pull)"
    elif [[ -e $dest ]]; then
        echo "$dest exists but isn't a git checkout; move it aside and retry." >&2
        exit 1
    else
        echo "==> Cloning $repo_url to $dest"
        "${shell[@]}" "git clone --depth 1 '$repo_url' '$dest'"
    fi

    # Piped into bash, stdin is this script, not the keyboard: hand the
    # installer the terminal so its prompts can be answered.
    local cmd
    cmd="cd '$dest' && ./install.sh"
    (($# > 0)) && cmd+=" $(printf '%q ' "$@")"
    if { : </dev/tty; } 2>/dev/null; then
        exec "${shell[@]}" "$cmd" </dev/tty
    else
        exec "${shell[@]}" "$cmd"
    fi
}

main "$@"
