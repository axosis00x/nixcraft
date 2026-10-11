#!/usr/bin/env bash
# nixcraft installer: adapts this flake to the current machine and user, lets
# you pick optional features, then builds it. Run from the cloned repo at
# ~/nixcraft on NixOS, as the user who will use the desktop (not root).
#
#   ./install.sh               ask for each value (Enter keeps the default)
#   ./install.sh --yes         accept every default without asking
#   ./install.sh --no-switch   write the config but don't build
#   ./install.sh --demo        walk through everything, change nothing
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
            sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
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

# Reads a value from the current settings.nix, so re-running the installer
# keeps earlier choices as the defaults.
current() {
    grep -oE "^\s*$1 = [^;]+;" settings.nix 2>/dev/null | head -1 | sed -E 's/.*= *"?([^";]*)"?;/\1/'
}

# ── preflight ───────────────────────────────────────────────────────────────
[[ $EUID -ne 0 ]] || die "Run this as your normal user, not root (it uses sudo where needed)."
if [[ ! -e /etc/NIXOS ]]; then
    $demo && warn "Not on NixOS; fine for a demo." || die "This installer is for NixOS."
fi
command -v git >/dev/null || die "git is missing. Try: nix-shell -p git pciutils --run ./install.sh"

repo=$(cd "$(dirname "$0")" && pwd)
cd "$repo"
[[ -f flake.nix && -d hosts/oneiros ]] || die "Run this from the nixcraft repository."

printf '\n%snixcraft installer%s%s\n' "$bold" "$reset" "$($demo && printf ' %s(demo: nothing will be changed)%s' "$cyan" "$reset")"
printf '%sAdapts the flake to this machine, then builds it.%s\n\n' "$dim" "$reset"

# ── 1. who and where ────────────────────────────────────────────────────────
printf '%s1. User and machine%s\n' "$bold" "$reset"
printf '%s   Already set these up while installing NixOS? Just press Enter to keep them.%s\n' "$dim" "$reset"
default_name=$(getent passwd "$USER" | cut -d: -f5 | cut -d, -f1)
default_tz=$(timedatectl show -p Timezone --value 2>/dev/null || true)

ask username "   Username:" "$USER"
ask full_name "   Full name:" "${default_name:-$username}"
ask hostname "   Hostname:" "$(hostname)"
ask timezone "   Timezone:" "${default_tz:-$(current timezone)}"

[[ $username =~ ^[a-z_][a-z0-9_-]*$ ]] || die "Invalid username: $username"
[[ $hostname =~ ^[A-Za-z0-9][A-Za-z0-9-]*$ ]] || die "Invalid hostname: $hostname"
[[ -e /etc/zoneinfo/$timezone || -e /usr/share/zoneinfo/$timezone ]] || warn "Timezone '$timezone' not found in zoneinfo; check it."

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

# ── 3. optional features ────────────────────────────────────────────────────
printf '\n%s3. Optional features%s\n' "$bold" "$reset"
printf '%s   The desktop itself (Hyprland, shell, fonts, theming, screenshots, login screen) is always installed.%s\n' "$dim" "$reset"

feature_keys=(virtualization games coding apps extras)
feature_desc=(
    "Virtualization   virt-manager/libvirt VMs and Waydroid (Android apps)"
    "Games            Steam"
    "Coding           Neovim, Zed, language toolchains, Claude Code"
    "Apps             browsers, Discord, LibreOffice, OBS, LocalSend, Obsidian…"
    "Extras           terminal toys and monitors: btop, cava, fastfetch, cmatrix…"
)
declare -A feature
for key in "${feature_keys[@]}"; do
    v=$(current "$key")
    feature[$key]=${v:-true}
done

show_features() {
    local i key mark
    for i in "${!feature_keys[@]}"; do
        key=${feature_keys[$i]}
        [[ ${feature[$key]} == true ]] && mark="${green}[x]${reset}" || mark="[ ]"
        printf '   %s %d. %s\n' "$mark" "$((i + 1))" "${feature_desc[$i]}"
    done
}

show_features
if ! $assume_yes; then
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
        show_features
    done
fi

# config/ is linked into ~/.config from /home/<user>/nixcraft (modules/user).
if [[ $repo != "/home/$username/nixcraft" ]]; then
    warn "The repo is at $repo, but configs are linked from /home/$username/nixcraft."
    warn "Move or clone it there (as $username) before switching, or ~/.config links will dangle."
    $demo || confirm "Continue anyway?" n || exit 1
fi

# ── 4. write the configuration ──────────────────────────────────────────────
printf '\n%s4. Configuration%s\n' "$bold" "$reset"
host_dir="hosts/$hostname"
if [[ ! -d $host_dir ]]; then
    info "Creating $host_dir from hosts/oneiros"
    run cp -r hosts/oneiros "$host_dir"
    # A new install keeps its own state version (never bump it later).
    state=$(grep -ho 'stateVersion *= *"[0-9.]*"' /etc/nixos/configuration.nix 2>/dev/null | grep -o '[0-9.]\+' | head -1 || true)
    if [[ -n $state ]]; then
        info "Keeping this install's stateVersion ($state)"
        run sed -i -E "s/(system\.stateVersion = )\"[0-9.]+\"/\1\"$state\"/" "$host_dir/configuration.nix"
        run sed -i -E "s/(home\.stateVersion = )\"[0-9.]+\"/\1\"$state\"/" "$host_dir/home.nix"
    fi
else
    info "Using existing $host_dir"
fi

if [[ $hostname != oneiros ]] || confirm "Regenerate hosts/oneiros/hardware-configuration.nix for this machine?" n; then
    info "Generating $host_dir/hardware-configuration.nix"
    if $demo; then
        run sudo nixos-generate-config --show-hardware-config '>' "$host_dir/hardware-configuration.nix"
    else
        sudo nixos-generate-config --show-hardware-config >"$host_dir/hardware-configuration.nix.new"
        mv "$host_dir/hardware-configuration.nix.new" "$host_dir/hardware-configuration.nix"
    fi
fi

info "Writing settings.nix"
write_file settings.nix <<EOF
# Who and what this system is for. flake.nix reads this and hands it to
# every module as \`settings\`; ./install.sh writes it for a new machine.
{
  # Login name and its home directory (/home/<username>). The repo must be
  # cloned to /home/<username>/nixcraft (config/ is linked from there).
  username = "$username";
  fullName = "$full_name";

  # Also names the host folder (hosts/<hostname>) and the flake output
  # (nixos-rebuild switch --flake ~/nixcraft#<hostname>).
  hostname = "$hostname";
  timezone = "$timezone";

  # Hardware specific to the original machine; turn off elsewhere.
  # NVIDIA Optimus (Intel + NVIDIA laptop graphics): modules/system/gpu
  nvidiaOptimus = $nvidia;
  # Extra ext4 drive mounted by UUID at ~/DataSSD: modules/system/storage
  dataDrive = $data_drive;

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

# apply-theme.sh / apply-shader.sh write absolute paths; point them at the
# new home so Hyprland and kitty find the theme on first login.
for f in config/hypr/theme.lua config/hypr/shader.lua config/kitty/theme.conf; do
    if [[ -f $f ]] && grep -qE "/home/[^/]+/" "$f" && ! grep -q "/home/$username/" "$f"; then
        info "Pointing $f at /home/$username"
        run sed -i -E "s#/home/[^/]+/#/home/$username/#g" "$f"
    fi
done

# Flakes only see files git knows about.
info "Staging files for the flake"
run git add -A

if grep -q 'axosis00x' modules/user/git/default.nix 2>/dev/null && [[ $username != axosis00x ]]; then
    warn "modules/user/git/default.nix has the original author's git name/email; change it to yours."
fi

# ── 5. build ────────────────────────────────────────────────────────────────
on_off() { [[ $1 == true ]] && printf '%son%s' "$green" "$reset" || printf '%soff%s' "$dim" "$reset"; }
printf '\n%sSummary%s\n' "$bold" "$reset"
printf '   user            %s (%s)\n   host            %s\n   timezone        %s\n' "$username" "$full_name" "$hostname" "$timezone"
printf '   nvidia optimus  %s\n   data drive      %s\n' "$(on_off $nvidia)" "$(on_off $data_drive)"
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
   4. Change features later by editing settings.nix (or re-running ./install.sh),
      then: sudo nixos-rebuild switch --flake ~/nixcraft#$hostname
EOF
