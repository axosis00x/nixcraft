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
    # Same markers as install.sh, colored only on a terminal.
    local blue='' green='' red='' reset=''
    if [[ -t 1 && -z ${NO_COLOR:-} ]]; then
        blue=$'\033[38;5;75m' green=$'\033[32m' red=$'\033[31m' reset=$'\033[0m'
    fi
    say() { printf '    %s•%s %s\n' "$blue" "$reset" "$1"; }
    fail() { printf '    %s✗ %s%s\n' "$red" "$1" "$reset" >&2; }

    local repo_url=${NIXCRAFT_REPO:-https://github.com/axosis00x/nixcraft}
    local dest=${NIXCRAFT_DIR:-$HOME/nixcraft}

    if [[ $EUID -eq 0 ]]; then
        fail "Run this as your normal user, not root (it uses sudo where needed)."
        exit 1
    fi
    if [[ ! -e /etc/NIXOS ]]; then
        fail "This installs a NixOS configuration; run it on NixOS."
        exit 1
    fi

    # git and lspci aren't on a fresh install; borrow them from nixpkgs.
    local shell=(nix-shell -p git pciutils --run)

    # Fetch them once up front with Nix's per-path download log hidden, so
    # it doesn't bury the installer; the log is shown only if it fails.
    echo
    say "Getting git and pciutils from nixpkgs (the first run downloads them)"
    local log
    log=$(mktemp)
    if ! "${shell[@]}" true >"$log" 2>&1; then
        cat "$log" >&2
        rm -f "$log"
        fail "Couldn't get git and pciutils from nixpkgs; check the network and retry."
        exit 1
    fi
    rm -f "$log"

    if [[ -d $dest/.git ]]; then
        printf '    %s✓%s Using the existing checkout at %s (update it with: git -C %s pull)\n' "$green" "$reset" "$dest" "$dest"
    elif [[ -e $dest ]]; then
        fail "$dest exists but isn't a git checkout; move it aside and retry."
        exit 1
    else
        say "Cloning $repo_url to $dest"
        "${shell[@]}" "git clone --quiet --depth 1 '$repo_url' '$dest'"
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
