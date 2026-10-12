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

bold=$'\033[1m' dim=$'\033[2m' green=$'\033[32m' yellow=$'\033[33m' red=$'\033[31m' cyan=$'\033[36m' reset=$'\033[0m'
info() { printf '%s==>%s %s\n' "$green" "$reset" "$1"; }
warn() { printf '%s!!%s  %s\n' "$yellow" "$reset" "$1"; }
die() {
    printf '%sxx%s  %s\n' "$red" "$reset" "$1" >&2
    exit 1
}

# In demo mode every change is printed instead of made.
run() {
    if $demo; then
        printf '%s[demo]%s would run: %s\n' "$cyan" "$reset" "$*"
    else
        "$@"
    fi
}

# write_file PATH < content
write_file() {
    local path=$1 content
    content=$(cat)
    if $demo; then
        printf '%s[demo]%s would write %s:\n' "$cyan" "$reset" "$path"
        printf '%s\n' "$content" | sed "s/^/${dim}    │${reset} /"
    else
        printf '%s\n' "$content" >"$path"
    fi
}

# ask VAR "Question" default
ask() {
    local __var=$1 question=$2 default=$3 reply
    if $assume_yes; then
        reply=$default
        printf '%s %s%s%s\n' "$question" "$dim" "$reply" "$reset"
    else
        read -r -p "$question ${dim}[$default]${reset} " reply
        reply=${reply:-$default}
    fi
    printf -v "$__var" '%s' "$reply"
}

# confirm "Question" default(y/n)
confirm() {
    local reply default=$2
    if $assume_yes; then
        printf '%s %s%s%s\n' "$1" "$dim" "$default" "$reset"
        [[ $default == y ]]
        return
    fi
    read -r -p "$1 ${dim}[$([[ $default == y ]] && echo Y/n || echo y/N)]${reset} " reply
    reply=${reply:-$default}
    [[ $reply =~ ^[Yy] ]]
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
        printf '   Timezone: %s%s%s\n' "$dim" "$timezone" "$reset"
        return
    fi
    while true; do
        read -r -p "   Timezone (type to search): ${dim}[$default]${reset} " reply
        reply=${reply:-$default}
        if grep -qxF "$reply" <<<"$zones"; then
            timezone=$reply
            return
        fi
        mapfile -t matches < <(grep -iF "$reply" <<<"$zones" | head -20)
        if ((${#matches[@]} == 0)); then
            warn "No timezone matches '$reply'. Try a city or region, e.g. london, tokyo, america/."
        elif ((${#matches[@]} == 1)); then
            timezone=${matches[0]}
            printf '   %s→ %s%s\n' "$dim" "$timezone" "$reset"
            return
        else
            for i in "${!matches[@]}"; do
                printf '     %2d. %s\n' "$((i + 1))" "${matches[$i]}"
            done
            read -r -p "   Pick a number (Enter to search again): " choice
            if [[ $choice =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#matches[@]})); then
                timezone=${matches[$((choice - 1))]}
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
        printf '   \033[1;38;5;%sm%s%s\n' "${shades[$i]}" "${rows[$i]}" "$reset"
    done
    printf '   %sby%s %saxosis00x%s\n\n' "$dim" "$reset" $'\033[38;5;75m' "$reset"
    $demo && printf '   %sdemo: nothing will be changed%s\n\n' "$cyan" "$reset"
    printf '   %sAdapts nixcraft to this machine, then builds it.%s\n\n' "$dim" "$reset"
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
printf '%s1. User and machine%s\n' "$bold" "$reset"
printf '%s   Already set these up while installing NixOS? Just press Enter to keep them.%s\n' "$dim" "$reset"
default_tz=$(timedatectl show -p Timezone --value 2>/dev/null || true)

ask username "   Username:" "$USER"
# The full-name default follows the username just entered: that account's
# own name if it exists, otherwise the username itself.
default_name=$(getent passwd "$username" | cut -d: -f5 | cut -d, -f1 || true)
ask full_name "   Full name:" "${default_name:-$username}"
ask hostname "   Hostname:" "$(hostname)"

[[ $username =~ ^[a-z_][a-z0-9_-]*$ ]] || die "Invalid username: $username"
[[ $hostname =~ ^[A-Za-z0-9][A-Za-z0-9-]*$ ]] || die "Invalid hostname: $hostname"
host_dir="hosts/$hostname"
settings_file="$host_dir/settings.nix"
[[ -f $settings_file ]] && info "Found $settings_file; its values are the defaults."
pick_timezone

# Git commit identity: this machine's previous answer, else whatever git
# already has, else the username. Leave the email blank to set it later.
default_git_name=$(current name)
default_git_email=$(current email)
[[ -n $default_git_name ]] || default_git_name=$(git config --global user.name 2>/dev/null || true)
[[ -n $default_git_email ]] || default_git_email=$(git config --global user.email 2>/dev/null || true)
ask git_name "   Git name:" "${default_git_name:-$username}"
while true; do
    ask git_email "   Git email (GitHub: Settings → Emails; blank = later):" "$default_git_email"
    [[ -z $git_email || $git_email =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]] && break
    $assume_yes && die "Invalid git email: $git_email"
    warn "That doesn't look like an email address."
done

if getent passwd "$username" >/dev/null; then
    info "User '$username' exists; it keeps its password, home and files."
else
    warn "User '$username' doesn't exist yet; NixOS creates it on switch (then: sudo passwd $username)."
fi

# ── 2. hardware ─────────────────────────────────────────────────────────────
printf '\n%s2. Hardware%s\n' "$bold" "$reset"
# Hybrid Intel + NVIDIA graphics → offer the Optimus module.
if command -v lspci >/dev/null && lspci | grep -qi 'vga.*nvidia\|3d.*nvidia' && lspci | grep -qi 'vga.*intel'; then
    default_nvidia=y
    printf '%s   Detected Intel + NVIDIA graphics.%s\n' "$dim" "$reset"
else
    default_nvidia=n
fi
nvidia=false
confirm "   Enable NVIDIA Optimus (Intel + NVIDIA hybrid) graphics?" "$default_nvidia" && nvidia=true

# The data drive is mounted by a UUID that only exists on the original
# machine; only offer it when that disk is actually present.
data_drive=false
data_uuid=$(grep -o 'by-uuid/[0-9a-f-]*' modules/system/storage/default.nix | cut -d/ -f2)
if [[ -n $data_uuid && -e /dev/disk/by-uuid/$data_uuid ]]; then
    confirm "   Mount the DataSSD drive at ~/DataSSD?" y && data_drive=true
fi

# UEFI → systemd-boot on the EFI partition; legacy BIOS → GRUB on the disk
# holding /. Getting this wrong leaves the machine unbootable, so confirm.
efi_mount=/boot
grub_device=""
if [[ -d /sys/firmware/efi ]]; then
    boot_loader=systemd-boot
    efi_mount=$(findmnt -rno TARGET -t vfat 2>/dev/null | grep -m1 '^/boot' || true)
    efi_mount=${efi_mount:-/boot}
    printf '%s   UEFI firmware: systemd-boot, EFI partition at %s.%s\n' "$dim" "$efi_mount" "$reset"
else
    boot_loader=grub
    root_disk=$(lsblk -no pkname "$(findmnt -no SOURCE /)" 2>/dev/null | head -1)
    printf '%s   Legacy BIOS firmware: GRUB.%s\n' "$dim" "$reset"
    ask grub_device "   Disk to install GRUB on:" "/dev/${root_disk:-sda}"
    [[ -b $grub_device ]] || warn "$grub_device isn't a block device; check it."
fi

# Inside a VM, turn on the guest agents (clipboard sharing with the host).
vm=false
virt=$(systemd-detect-virt --vm 2>/dev/null || true)
if [[ -n $virt && $virt != none ]]; then
    vm=true
    printf '%s   Running in a virtual machine (%s): guest clipboard agent on.%s\n' "$dim" "$virt" "$reset"
fi

# ── 3. optional features ────────────────────────────────────────────────────
printf '\n%s3. Optional features%s\n' "$bold" "$reset"
printf '%s   The desktop itself (Hyprland, shell, fonts, theming, screenshots, login screen) is always installed.%s\n' "$dim" "$reset"

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
            pointer="${cyan}❯${reset}"
            name="${bold}${feature_name[$i]}${reset}"
        else
            pointer=" "
            name=${feature_name[$i]}
        fi
        printf '\033[2K   %s %s %-16b %s%s%s\n' "$pointer" "$box" "$name" "$dim" "${feature_desc[$i]}" "$reset"
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
        printf '\033[2K   %s↑↓ move · space toggle · a all · n none · enter confirm%s\n' "$dim" "$reset"
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
        read -r -p "   Toggle by number (e.g. \"1 3\"), a = all, n = none, Enter = done: " picks
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

# config/ is linked into ~/.config from /home/<user>/nixcraft (modules/user).
if [[ $repo != "/home/$username/nixcraft" ]]; then
    warn "The repo is at $repo, but configs are linked from /home/$username/nixcraft."
    warn "Move or clone it there (as $username) before switching, or ~/.config links will dangle."
    $demo || confirm "Continue anyway?" n || exit 1
fi

# ── 4. write the configuration ──────────────────────────────────────────────
printf '\n%s4. Configuration%s\n' "$bold" "$reset"
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

if [[ ! -f $host_dir/hardware-configuration.nix ]] || confirm "Regenerate $host_dir/hardware-configuration.nix?" n; then
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
# hands this file to every module as \`settings\`. ./install.sh writes it.
{
  # Login name and its home directory (/home/<username>). The repo must be
  # cloned to /home/<username>/nixcraft (config/ is linked from there).
  username = "$username";
  fullName = "$full_name";

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

[[ -n $git_email ]] || warn "No git email set; add it to $settings_file later (git.email)."

# ── 5. GitHub over SSH ──────────────────────────────────────────────────────
# Optional: a key for pushing to GitHub. ssh picks up ~/.ssh/id_ed25519 on
# its own and the agent (modules/user/git) remembers it, so no ssh config is
# needed. Skipped with --yes: someone has to paste the key into GitHub.
printf '\n%s5. GitHub over SSH%s\n' "$bold" "$reset"
ssh_status=skipped
key="$HOME/.ssh/id_ed25519"
if $assume_yes; then
    printf '%s   Skipped with --yes; run ./install.sh again to set it up.%s\n' "$dim" "$reset"
elif confirm "   Set up an SSH key for pushing to GitHub?" y; then
    if [[ -f $key.pub ]]; then
        info "Using your existing key, $key"
    else
        info "Creating $key (a passphrase is optional; Enter for none)"
        run mkdir -p -m 700 "$HOME/.ssh"
        run ssh-keygen -t ed25519 -C "${git_email:-$username@$hostname}" -f "$key"
    fi

    if $demo; then
        run wl-copy '<' "$key.pub"
        printf '%s[demo]%s would ask you to add it at https://github.com/settings/ssh/new, then test it with: ssh -T git@github.com\n' "$cyan" "$reset"
    else
        printf '\n   Your public key:\n\n   %s%s%s\n\n' "$green" "$(cat "$key.pub")" "$reset"
        if command -v wl-copy >/dev/null && [[ -n ${WAYLAND_DISPLAY:-} ]] && wl-copy <"$key.pub" 2>/dev/null; then
            info "Copied it to the clipboard."
        fi
        printf '   Add it on GitHub: %shttps://github.com/settings/ssh/new%s\n' "$cyan" "$reset"
        printf '   %s(title: anything, e.g. %s; key type: Authentication Key)%s\n' "$dim" "$hostname" "$reset"
        read -r -p "   Press Enter once it's added (or type s to skip the check) " reply
        if [[ $reply != s ]]; then
            # GitHub answers "Hi <user>! You've successfully authenticated…"
            # and exits 1 (no shell access), so judge by the message.
            reply=$(ssh -T -o StrictHostKeyChecking=accept-new -o BatchMode=yes git@github.com 2>&1 || true)
            if [[ $reply == *"successfully authenticated"* ]]; then
                info "GitHub says: ${reply%%!*}!"
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
on_off() { [[ $1 == true ]] && printf '%son%s' "$green" "$reset" || printf '%soff%s' "$dim" "$reset"; }
printf '\n%sSummary%s\n' "$bold" "$reset"
printf '   user            %s (%s)\n   host            %s\n   timezone        %s\n' "$username" "$full_name" "$hostname" "$timezone"
printf '   git             %s <%s>\n' "$git_name" "${git_email:-not set}"
printf '   github ssh      %s\n' "$ssh_status"
printf '   boot loader     %s\n' "$boot_loader${grub_device:+ on $grub_device}"
printf '   nvidia optimus  %s\n   data drive      %s\n' "$(on_off $nvidia)" "$(on_off $data_drive)"
printf '   virtual machine %s\n' "$(on_off $vm)"
for key in "${feature_keys[@]}"; do
    printf '   %-15s %s\n' "$key" "$(on_off "${feature[$key]}")"
done
echo

rebuild=(sudo nixos-rebuild switch --flake "$repo#$hostname" --option experimental-features "nix-command flakes")

if $demo; then
    run "${rebuild[@]}"
    printf '\n%sDemo finished; nothing was changed.%s Run ./install.sh without --demo to do it for real.\n' "$cyan" "$reset"
    exit 0
fi

if ! $do_switch; then
    info "Prepared. Build with: sudo nixos-rebuild switch --flake $repo#$hostname"
    exit 0
fi

confirm "Build and switch to it now?" y || {
    info "Skipped. Build later with: sudo nixos-rebuild switch --flake $repo#$hostname"
    exit 0
}

info "Building (the first build downloads a lot; this can take a while)"
# Flakes may not be enabled yet on a fresh install; this config enables them.
"${rebuild[@]}"

printf '\n%sDone.%s Next:\n' "$green" "$reset"
cat <<EOF
   1. Reboot (or log out) and pick Hyprland at the login screen.
   2. Wallpapers live outside the repo: put images in ~/Pictures/wallpapers/<theme>/.
   3. In tmux, install plugins with: prefix, then I.
   4. Change features later by editing $settings_file (or re-running ./install.sh),
      then: sudo nixos-rebuild switch --flake ~/nixcraft#$hostname
EOF
