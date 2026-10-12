#!/usr/bin/env bash
# nixcraft installer: adapts this flake to the current machine and user, lets
# you pick optional features, then builds it. Run from the cloned repo at
# ~/nixcraft on NixOS, as the user who will use the desktop (not root).
#
#   ./install.sh               ask for each value (Enter keeps the default)
#   ./install.sh --yes         accept every default without asking
#   ./install.sh --no-switch   write the config but don't build
#   ./install.sh --demo        walk through everything, change nothing
# ask() assigns its variable by name (printf -v), which shellcheck cannot see.
# shellcheck disable=SC2154
set -euo pipefail

assume_yes=false
do_switch=true
demo=false
for arg in "$@"; do
    case "$arg" in
        -y | --yes) assume_yes=true ;;
        --no-switch) do_switch=false ;;
        --demo | --dry-run) demo=true ;;
        -h | --help)
            sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            echo "Unknown option: $arg (see --help)" >&2
            exit 2
            ;;
    esac
done

# Colors and in-place redraws only on a terminal (NO_COLOR turns colors off).
tty=false
[[ -t 1 ]] && tty=true
if $tty && [[ -z ${NO_COLOR:-} ]]; then
    bold=$'\033[1m' dim=$'\033[2m' green=$'\033[32m' yellow=$'\033[33m' red=$'\033[31m'
    cyan=$'\033[36m' accent=$'\033[38;5;75m' reset=$'\033[0m'
else
    bold='' dim='' green='' yellow='' red='' cyan='' accent='' reset=''
fi

# Everything sits on one 4-space indent under 2-space section headings:
#   ✓ done   • working   ! warning   ✗ error   (dim) a note
info() { printf '    %s•%s %s\n' "$accent" "$reset" "$1"; }
ok() { printf '    %s✓%s %s\n' "$green" "$reset" "$1"; }
warn() { printf '    %s!%s %s\n' "$yellow" "$reset" "$1"; }
note() { printf '    %s%s%s\n' "$dim" "$1" "$reset"; }
die() {
    printf '\n    %s✗ %s%s\n' "$red" "$1" "$reset" >&2
    exit 1
}

# section "Title": a numbered heading ("2/5  Hardware") over a thin rule;
# heading "Title" is the same without the number.
steps=5
step=0
rule=$(printf '─%.0s' {1..56})
heading() { printf '\n  %s%s%s\n  %s%s%s\n' "$bold" "$1" "$reset" "$dim" "$rule" "$reset"; }
section() {
    step=$((step + 1))
    printf '\n  %s%s%d/%d%s  %s%s%s\n  %s%s%s\n' "$bold" "$accent" "$step" "$steps" "$reset" "$bold" "$1" "$reset" "$dim" "$rule" "$reset"
}

# An answered prompt, left on screen as an aligned "Label  value" row.
answered() { printf '    %-14s %s%s%s\n' "$1" "$accent" "${2:-—}" "$reset"; }
# Clears the prompt line just answered, so answered() can redraw it.
clear_prompt() { if $tty; then printf '\033[1A\033[2K'; fi; }

# In demo mode every change is printed instead of made.
run() {
    if $demo; then
        printf '    %sdemo%s %swould run%s %s\n' "$cyan" "$reset" "$dim" "$reset" "$*"
    else
        "$@"
    fi
}

# write_file PATH < content
write_file() {
    local path=$1 content
    content=$(cat)
    if $demo; then
        printf '    %sdemo%s %swould write%s %s\n' "$cyan" "$reset" "$dim" "$reset" "$path"
        printf '%s\n' "$content" | sed "s/^/      ${dim}│${reset} /"
    else
        printf '%s\n' "$content" >"$path"
    fi
}

# ask VAR "Label" default: one aligned prompt row; Enter keeps the default.
ask() {
    local __var=$1 label=$2 default=$3 reply
    if $assume_yes; then
        reply=$default
    else
        read -r -p "$(printf '    %-14s %s%s%s %s›%s ' "$label" "$dim" "${default:-—}" "$reset" "$accent" "$reset")" reply
        reply=${reply:-$default}
        clear_prompt
    fi
    answered "$label" "$reply"
    printf -v "$__var" '%s' "$reply"
}

# confirm "Question?" default(y/n): answers show as a green yes or a dim no.
confirm() {
    local question=$1 default=$2 reply hint=y/N
    [[ $default == y ]] && hint=Y/n
    if $assume_yes; then
        reply=$default
    else
        read -r -p "$(printf '    %s %s%s%s %s›%s ' "$question" "$dim" "$hint" "$reset" "$accent" "$reset")" reply
        reply=${reply:-$default}
        clear_prompt
    fi
    if [[ $reply =~ ^[Yy] ]]; then
        printf '    %s %syes%s\n' "$question" "$green" "$reset"
    else
        printf '    %s %sno%s\n' "$question" "$dim" "$reset"
        return 1
    fi
}

# Reads a value from this machine's existing settings (hosts/<hostname>/
# settings.nix, once the hostname is known), so re-running the installer
# keeps earlier choices as the defaults.
settings_file=/dev/null
current() {
    { grep -oE "^\s*$1 = [^;]+;" "$settings_file" 2>/dev/null || true; } | head -1 | sed -E 's/.*= *"?([^";]*)"?;/\1/'
}

# Timezone prompt with search: Enter keeps the default, an exact name is
# taken as-is, anything else ("kath", "tokyo", "europe/") lists matching
# zones to pick from by number.
pick_timezone() {
    local default=${default_tz:-$(current timezone)}
    default=${default:-UTC}
    local zones reply matches i choice
    zones=$(timedatectl list-timezones 2>/dev/null || (cd /etc/zoneinfo 2>/dev/null && find . -type f | sed 's#^\./##' | sort))
    if $assume_yes; then
        timezone=$default
        answered Timezone "$timezone"
        return
    fi
    while true; do
        read -r -p "$(printf '    %-14s %s%s%s %s›%s ' Timezone "$dim" "$default" "$reset" "$accent" "$reset")" reply
        reply=${reply:-$default}
        if grep -qxF "$reply" <<<"$zones"; then
            timezone=$reply
            clear_prompt
            answered Timezone "$timezone"
            return
        fi
        mapfile -t matches < <(grep -iF "$reply" <<<"$zones" | head -20)
        if ((${#matches[@]} == 0)); then
            warn "No timezone matches '$reply'. Try a city or region, e.g. london, tokyo, america/."
        elif ((${#matches[@]} == 1)); then
            timezone=${matches[0]}
            clear_prompt
            answered Timezone "$timezone"
            return
        else
            for i in "${!matches[@]}"; do
                printf '      %s%2d%s  %s\n' "$accent" "$((i + 1))" "$reset" "${matches[$i]}"
            done
            read -r -p "$(printf '    %sPick a number (Enter to search again)%s %s›%s ' "$dim" "$reset" "$accent" "$reset")" choice
            if [[ $choice =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#matches[@]})); then
                timezone=${matches[$((choice - 1))]}
                answered Timezone "$timezone"
                return
            fi
        fi
    done
}

# "nixcraft" in figlet's standard font, shaded cyan to blue, with the
# author underneath. A quoted heredoc keeps the backslashes and quotes as-is.
banner() {
    local rows shades=(87 81 75 69 63) i
    mapfile -t rows <<'BANNER'
       _                     __ _
 _ __ (_)_  _____ _ __ __ _ / _| |_
| '_ \| \ \/ / __| '__/ _` | |_| __|
| | | | |>  < (__| | | (_| |  _| |_
|_| |_|_/_/\_\___|_|  \__,_|_|  \__|
BANNER
    echo
    for i in "${!rows[@]}"; do
        if [[ -n $reset ]]; then
            printf '  \033[1;38;5;%sm%s%s\n' "${shades[$i]}" "${rows[$i]}" "$reset"
        else
            printf '  %s\n' "${rows[$i]}"
        fi
    done
    printf '  %sby%s %saxosis00x%s\n\n' "$dim" "$reset" "$accent" "$reset"
    printf '  %sAdapts nixcraft to this machine, then builds it.%s\n' "$dim" "$reset"
    $demo && printf '  %s● demo%s %snothing will be changed%s\n' "$cyan" "$reset" "$dim" "$reset"
    return 0
}

# ── preflight ───────────────────────────────────────────────────────────────
[[ $EUID -ne 0 ]] || die "Run this as your normal user, not root (it uses sudo where needed)."
if [[ ! -e /etc/NIXOS ]]; then
    $demo && warn "Not on NixOS; fine for a demo." || die "This installer is for NixOS."
fi
command -v git >/dev/null || die "git is missing. Try: nix-shell -p git pciutils --run ./install.sh"

repo=$(cd "$(dirname "$0")" && pwd)
cd "$repo"
[[ -f flake.nix && -d hosts && -d modules/host ]] || die "Run this from the nixcraft repository."

banner

# ── 1. who and where ────────────────────────────────────────────────────────
section "User and machine"
note "Already set these up while installing NixOS? Press Enter to keep them."
default_tz=$(timedatectl show -p Timezone --value 2>/dev/null || true)

ask username "Username" "$USER"
# The full-name default follows the username just entered: that account's
# own name if it exists, otherwise the username itself.
default_name=$(getent passwd "$username" | cut -d: -f5 | cut -d, -f1 || true)
ask full_name "Full name" "${default_name:-$username}"
ask hostname "Hostname" "$(hostname)"

[[ $username =~ ^[a-z_][a-z0-9_-]*$ ]] || die "Invalid username: $username"
[[ $hostname =~ ^[A-Za-z0-9][A-Za-z0-9-]*$ ]] || die "Invalid hostname: $hostname"
host_dir="hosts/$hostname"
settings_file="$host_dir/settings.nix"
[[ -f $settings_file ]] && ok "Found $settings_file; its values are the defaults."
pick_timezone

# Git commit identity: this machine's previous answer, else whatever git
# already has, else the username. Leave the email blank to set it later.
default_git_name=$(current name)
default_git_email=$(current email)
[[ -n $default_git_name ]] || default_git_name=$(git config --global user.name 2>/dev/null || true)
[[ -n $default_git_email ]] || default_git_email=$(git config --global user.email 2>/dev/null || true)
ask git_name "Git name" "${default_git_name:-$username}"
$assume_yes || note "Your GitHub address is under GitHub → Settings → Emails; blank sets it later."
while true; do
    ask git_email "Git email" "$default_git_email"
    [[ -z $git_email || $git_email =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]] && break
    $assume_yes && die "Invalid git email: $git_email"
    warn "That doesn't look like an email address."
done

if getent passwd "$username" >/dev/null; then
    ok "User '$username' exists; it keeps its password, home and files."
else
    warn "User '$username' doesn't exist yet; NixOS creates it on switch (then: sudo passwd $username)."
fi

# ── 2. hardware ─────────────────────────────────────────────────────────────
section "Hardware"
# Hybrid Intel + NVIDIA graphics → offer the Optimus module.
if command -v lspci >/dev/null && lspci | grep -qi 'vga.*nvidia\|3d.*nvidia' && lspci | grep -qi 'vga.*intel'; then
    default_nvidia=y
    note "Detected Intel + NVIDIA graphics."
else
    default_nvidia=n
fi
nvidia=false
confirm "NVIDIA Optimus (Intel + NVIDIA hybrid) graphics?" "$default_nvidia" && nvidia=true

# The data drive is mounted by a UUID that only exists on the original
# machine; only offer it when that disk is actually present.
data_drive=false
data_uuid=$(grep -o 'by-uuid/[0-9a-f-]*' modules/system/storage/default.nix | cut -d/ -f2)
if [[ -n $data_uuid && -e /dev/disk/by-uuid/$data_uuid ]]; then
    confirm "Mount the DataSSD drive at ~/DataSSD?" y && data_drive=true
fi

# UEFI → systemd-boot on the EFI partition; legacy BIOS → GRUB on the disk
# holding /. Getting this wrong leaves the machine unbootable, so confirm.
efi_mount=/boot
grub_device=""
if [[ -d /sys/firmware/efi ]]; then
    boot_loader=systemd-boot
    efi_mount=$(findmnt -rno TARGET -t vfat 2>/dev/null | grep -m1 '^/boot' || true)
    efi_mount=${efi_mount:-/boot}
    note "UEFI firmware: systemd-boot, EFI partition at $efi_mount."
else
    boot_loader=grub
    root_disk=$(lsblk -no pkname "$(findmnt -no SOURCE /)" 2>/dev/null | head -1)
    note "Legacy BIOS firmware: GRUB."
    ask grub_device "GRUB disk" "/dev/${root_disk:-sda}"
    [[ -b $grub_device ]] || warn "$grub_device isn't a block device; check it."
fi

# Inside a VM, turn on the guest agents (clipboard sharing with the host).
vm=false
virt=$(systemd-detect-virt --vm 2>/dev/null || true)
if [[ -n $virt && $virt != none ]]; then
    vm=true
    note "Running in a virtual machine ($virt): guest clipboard agent on."
fi

# ── 3. optional features ────────────────────────────────────────────────────
section "Optional features"
note "The desktop itself (Hyprland, shell, fonts, theming, screenshots, login screen)"
note "is always installed."

feature_keys=(virtualization games coding apps extras)
feature_name=(Virtualization Games Coding Apps Extras)
feature_desc=(
    "virt-manager/libvirt VMs and Waydroid (Android apps)"
    "Steam"
    "Neovim, Zed, language toolchains, Claude Code"
    "browsers, Discord, LibreOffice, OBS, LocalSend, Obsidian…"
    "terminal toys and monitors: btop, cava, fastfetch, cmatrix…"
)
declare -A feature
for key in "${feature_keys[@]}"; do
    v=$(current "$key")
    feature[$key]=${v:-true}
done

# One line per feature; `cursor` (-1 for none) gets the pointer.
draw_features() {
    local cursor=$1 i key box pointer name
    for i in "${!feature_keys[@]}"; do
        key=${feature_keys[$i]}
        [[ ${feature[$key]} == true ]] && box="${green}◉${reset}" || box="${dim}○${reset}"
        if ((i == cursor)); then
            pointer="${accent}❯${reset}"
            name="${bold}${feature_name[$i]}${reset}"
        else
            pointer=" "
            name=${feature_name[$i]}
        fi
        # \033[2K clears the line for in-place redraws (terminals only).
        $tty && printf '\033[2K'
        printf '    %s %s %-16b %s%s%s\n' "$pointer" "$box" "$name" "$dim" "${feature_desc[$i]}" "$reset"
    done
}

# Arrow-key checklist: ↑↓ or j/k move, Space toggles, a/n select all/none,
# Enter confirms. Redraws in place; the cursor is hidden while it runs.
select_features() {
    local cursor=0 count=${#feature_keys[@]} k rest key
    printf '\033[?25l'
    trap 'printf "\033[?25h"' EXIT
    while true; do
        draw_features "$cursor"
        printf '\033[2K      %s↑↓ move · space toggle · a all · n none · enter confirm%s\n' "$dim" "$reset"
        IFS= read -rsn1 k
        if [[ $k == $'\033' ]]; then
            read -rsn2 -t 0.05 rest || true
            k+=$rest
        fi
        case "$k" in
            $'\033[A' | k) cursor=$(((cursor - 1 + count) % count)) ;;
            $'\033[B' | j) cursor=$(((cursor + 1) % count)) ;;
            " ")
                key=${feature_keys[$cursor]}
                [[ ${feature[$key]} == true ]] && feature[$key]=false || feature[$key]=true
                ;;
            a) for key in "${feature_keys[@]}"; do feature[$key]=true; done ;;
            n) for key in "${feature_keys[@]}"; do feature[$key]=false; done ;;
            "") break ;;
        esac
        printf '\033[%dA' $((count + 1))
    done
    # Leave the final choices on screen, without the pointer or help line.
    printf '\033[%dA' $((count + 1))
    draw_features -1
    printf '\033[2K'
    printf '\033[?25h'
}

# Without a keyboard (piped input), fall back to typing numbers.
select_features_by_number() {
    local picks p key
    draw_features -1
    while true; do
        read -r -p "$(printf '    %sToggle by number ("1 3"), a all, n none, Enter done%s %s›%s ' "$dim" "$reset" "$accent" "$reset")" picks
        [[ -z $picks ]] && break
        for p in $picks; do
            case "$p" in
                a) for key in "${feature_keys[@]}"; do feature[$key]=true; done ;;
                n) for key in "${feature_keys[@]}"; do feature[$key]=false; done ;;
                *)
                    if [[ $p =~ ^[0-9]+$ ]] && ((p >= 1 && p <= ${#feature_keys[@]})); then
                        key=${feature_keys[$((p - 1))]}
                        [[ ${feature[$key]} == true ]] && feature[$key]=false || feature[$key]=true
                    else
                        warn "Ignoring '$p'"
                    fi
                    ;;
            esac
        done
        draw_features -1
    done
}

if $assume_yes; then
    draw_features -1
elif [[ -t 0 && -t 1 ]]; then
    select_features
else
    select_features_by_number
fi

# config/ is linked into ~/.config from wherever the repo is (repoPath
# below), so it can live anywhere the user can read; another user's home
# usually can't be.
if [[ $repo != "/home/$username/"* ]]; then
    warn "The repo is at $repo, outside /home/$username; $username must be able to read it."
    $demo || confirm "Continue anyway?" n || exit 1
fi

# ── 4. write the configuration ──────────────────────────────────────────────
section "Configuration"
# A new install keeps its own state version (never bump it later): the
# existing host's, else the one /etc/nixos was installed with.
state=$(current stateVersion)
[[ -n $state ]] || state=$(grep -ho 'stateVersion *= *"[0-9.]*"' /etc/nixos/configuration.nix 2>/dev/null | grep -o '[0-9.]\+' | head -1 || true)
[[ -n $state ]] || state=$(nixos-version 2>/dev/null | cut -d. -f1-2)

if [[ -d $host_dir ]]; then
    info "Updating $host_dir"
else
    info "Creating $host_dir"
    run mkdir -p "$host_dir"
fi

if [[ ! -f $host_dir/hardware-configuration.nix ]] || confirm "Regenerate hardware-configuration.nix?" n; then
    info "Generating $host_dir/hardware-configuration.nix"
    if $demo; then
        run sudo nixos-generate-config --show-hardware-config '>' "$host_dir/hardware-configuration.nix"
    else
        # The redirect runs as the user on purpose: the file belongs in their repo.
        # shellcheck disable=SC2024
        sudo nixos-generate-config --show-hardware-config >"$host_dir/hardware-configuration.nix.new"
        mv "$host_dir/hardware-configuration.nix.new" "$host_dir/hardware-configuration.nix"
    fi
fi

info "Writing $settings_file"
write_file "$settings_file" <<EOF
# This machine's settings. Every folder in hosts/ is one machine, named after
# its hostname; flake.nix builds each as nixosConfigurations.<folder> and
# hands this file to every module as \`settings\`. ./install.sh writes it;
# modules/settings.nix lists every option, its type and its default.
{
  # Login name and its home directory (/home/<username>).
  username = "$username";
  fullName = "$full_name";

  # Where this repo is cloned; config/ is linked into ~/.config from here.
  repoPath = "$repo";

  # Git commit identity (an empty string leaves it unset).
  git = {
    name = "$git_name";
    email = "$git_email";
  };

  # The hostname is this folder's name (hosts/<hostname>), also used as
  # the flake output: nixos-rebuild switch --flake ~/nixcraft#<hostname>
  timezone = "$timezone";

  # Release this machine was first installed with; never bump it.
  stateVersion = "$state";

  # "systemd-boot" for UEFI (efiMount = the EFI partition's mount point),
  # "grub" for legacy BIOS (grubDevice = the boot disk, e.g. /dev/sda).
  boot = {
    loader = "$boot_loader";
    efiMount = "$efi_mount";
    grubDevice = "$grub_device";
  };

  # Hardware specific to the original machine; turn off elsewhere.
  # NVIDIA Optimus (Intel + NVIDIA laptop graphics): modules/system/gpu
  nvidiaOptimus = $nvidia;
  # Extra ext4 drive mounted by UUID at ~/DataSSD: modules/system/storage
  dataDrive = $data_drive;
  # Running inside a virtual machine (enables the guest clipboard agent).
  vm = $vm;

  # Optional parts; the desktop itself (Hyprland, shell, fonts, theming,
  # screenshots, login screen) is always installed.
  features = {
    virtualization = ${feature[virtualization]}; # virt-manager/libvirt and Waydroid (Android apps)
    games = ${feature[games]}; # Steam
    coding = ${feature[coding]}; # editors (Neovim, Zed), language toolchains, Claude Code
    apps = ${feature[apps]}; # browsers, Discord, LibreOffice, OBS, LocalSend, Obsidian…
    extras = ${feature[extras]}; # terminal toys and monitors (btop, cava, fastfetch, cmatrix…)
  };
}
EOF

# Flakes only see files git knows about.
info "Staging files for the flake"
run git add -A

ok "Configuration written"
[[ -n $git_email ]] || warn "No git email set; add it to $settings_file later (git.email)."

# ── 5. GitHub over SSH ──────────────────────────────────────────────────────
# Optional: a key for pushing to GitHub. ssh picks up ~/.ssh/id_ed25519 on
# its own and the agent (modules/user/git) remembers it, so no ssh config is
# needed. Skipped with --yes: someone has to paste the key into GitHub.
section "GitHub over SSH"
ssh_status=skipped
key="$HOME/.ssh/id_ed25519"
if $assume_yes; then
    note "Skipped with --yes; run ./install.sh again to set it up."
elif confirm "Set up an SSH key for pushing to GitHub?" y; then
    if [[ -f $key.pub ]]; then
        ok "Using your existing key, $key"
    else
        info "Creating $key (a passphrase is optional; Enter for none)"
        run mkdir -p -m 700 "$HOME/.ssh"
        run ssh-keygen -t ed25519 -C "${git_email:-$username@$hostname}" -f "$key"
    fi

    if $demo; then
        run wl-copy '<' "$key.pub"
        printf '    %sdemo%s %swould ask you to add it at%s https://github.com/settings/ssh/new\n' "$cyan" "$reset" "$dim" "$reset"
    else
        printf '\n    Your public key:\n\n      %s%s%s\n\n' "$accent" "$(cat "$key.pub")" "$reset"
        if command -v wl-copy >/dev/null && [[ -n ${WAYLAND_DISPLAY:-} ]] && wl-copy <"$key.pub" 2>/dev/null; then
            ok "Copied it to the clipboard."
        fi
        printf '    Add it on GitHub: %shttps://github.com/settings/ssh/new%s\n' "$cyan" "$reset"
        note "(title: anything, e.g. $hostname; key type: Authentication Key)"
        read -r -p "$(printf '    Press Enter once it is added %s(s skips the check)%s %s›%s ' "$dim" "$reset" "$accent" "$reset")" reply
        if [[ $reply != s ]]; then
            # GitHub answers "Hi <user>! You've successfully authenticated…"
            # and exits 1 (no shell access), so judge by the message.
            reply=$(ssh -T -o StrictHostKeyChecking=accept-new -o BatchMode=yes git@github.com 2>&1 || true)
            if [[ $reply == *"successfully authenticated"* ]]; then
                ok "GitHub says: ${reply%%!*}!"
                ssh_status=connected
            else
                warn "GitHub didn't accept the key yet: ${reply:-no answer}"
                warn "Check it's added, then test with: ssh -T git@github.com"
                ssh_status="key ready, not verified"
            fi
        else
            ssh_status="key ready"
        fi
    fi
fi

# ── 6. build ────────────────────────────────────────────────────────────────
# dot NAME true|false: a green ● for on, a dim ○ for off.
dot() {
    if [[ $2 == true ]]; then
        printf '%s●%s %s  ' "$green" "$reset" "$1"
    else
        printf '%s○ %s%s  ' "$dim" "$1" "$reset"
    fi
}
row() { printf '    %-14s %s\n' "$1" "$2"; }

heading "Summary"
row User "$username ${dim}($full_name)${reset}"
row Host "$hostname"
row Timezone "$timezone"
row Git "$git_name ${dim}<${git_email:-not set}>${reset}"
row "GitHub SSH" "$ssh_status"
row "Boot loader" "$boot_loader${grub_device:+ on $grub_device}"
row Hardware "$(dot "NVIDIA Optimus" "$nvidia")$(dot "data drive" "$data_drive")$(dot "VM guest" "$vm")"
features_line=""
for key in "${feature_keys[@]}"; do
    features_line+=$(dot "$key" "${feature[$key]}")
done
row Features "$features_line"
echo

rebuild=(sudo nixos-rebuild switch --flake "$repo#$hostname" --option experimental-features "nix-command flakes")

if $demo; then
    run "${rebuild[@]}"
    printf '\n  %s✓ Demo finished; nothing was changed.%s %sRun ./install.sh without --demo to do it for real.%s\n\n' "$cyan" "$reset" "$dim" "$reset"
    exit 0
fi

if ! $do_switch; then
    ok "Prepared. Build with: sudo nixos-rebuild switch --flake $repo#$hostname"
    exit 0
fi

confirm "Build and switch to it now?" y || {
    info "Skipped. Build later with: sudo nixos-rebuild switch --flake $repo#$hostname"
    exit 0
}

heading "Build"
info "Building (the first build downloads a lot; this can take a while)"
# Flakes may not be enabled yet on a fresh install; this config enables them.
"${rebuild[@]}"

printf '\n  %s%s✓ Done.%s Next:\n\n' "$bold" "$green" "$reset"
cat <<EOF
    ${accent}1${reset}  Reboot (or log out) and pick Hyprland at the login screen.
    ${accent}2${reset}  Wallpapers live outside the repo: put images in ~/Pictures/wallpapers/<theme>/.
    ${accent}3${reset}  In tmux, install plugins with: prefix, then I.
    ${accent}4${reset}  Change features later by editing $settings_file (or re-running ./install.sh),
       then: ${dim}sudo nixos-rebuild switch --flake $repo#$hostname${reset}

EOF
