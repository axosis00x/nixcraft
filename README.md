## nixcraft

Curiosity brought me here. This is nixcraft, a NixOS configuration for my desktop with hyprland.

## Showcase

<img src='/assets/showcase/one.png' alt='showcase' width='100%'>
<p align="center">
  <table>
    <tr>
      <td><img src='/assets/showcase/two.png' alt='showcase' width='100%'></td>
      <td><img src='/assets/showcase/three.png' alt='showcase' width='100%'></td>
    </tr>
    <tr>
      <td><img src='/assets/showcase/four.png' alt='showcase' width='100%'></td>
      <td><img src='/assets/showcase/five.png' alt='showcase' width='100%'></td>
    </tr>
    <tr>
      <td><img src='/assets/showcase/six.png' alt='showcase' width='100%'></td>
      <td><img src='/assets/showcase/sev.png' alt='showcase' width='100%'></td>
    </tr>
  </table>
</p>
<img src='/assets/showcase/catppuccin.png' alt='showcase' width='100%'>

## Installation

Each machine is a folder in `hosts/`, named after its hostname, holding just
two files: `settings.nix` (username, timezone, boot loader, hardware toggles,
optional features) and `hardware-configuration.nix`. Everything else is shared
from `modules/`. The installer creates that folder for you, so it works with
any username and hostname, and several machines can share this repo without
touching each other. See [`hosts/oneiros/settings.nix`](hosts/oneiros/settings.nix)
for an example.

### Quick install

On a fresh NixOS system, logged in as your user (not root):

```bash
curl -fsSL https://subashlamatamang.com.np/install | bash
```

This clones the repo to `~/nixcraft` and runs the installer described below.
To see what it would do without changing anything, run the demo first:

```bash
curl -fsSL https://subashlamatamang.com.np/install | bash -s -- --demo
```

Prefer to do it step by step? Read on.

### 1. Install NixOS and get online

Install NixOS normally (any edition), create your user, boot into the new
system, and connect to the internet.

### 2. Clone the repository to `~/nixcraft`

Git isn't installed on a fresh system, so borrow it for one command:

```bash
nix-shell -p git --run "git clone https://github.com/axosis00x/nixcraft ~/nixcraft"
cd ~/nixcraft
```

Clone it into the home of the user who will use the desktop, at exactly
`~/nixcraft`: the configs in `config/` are linked into `~/.config` from there.

### 3. Run the installer

```bash
nix-shell -p git pciutils --run ./install.sh
```

It asks for each value, with sensible defaults already filled in (press Enter
to keep one):

| Prompt         | Default                                                 |
| -------------- | ------------------------------------------------------- |
| Username       | the user running it                                     |
| Full name      | that user's full name (or the username)                 |
| Hostname       | the current hostname                                    |
| Timezone       | the system timezone; type part of a city to search      |
| NVIDIA Optimus | **yes** only if both Intel and NVIDIA GPUs are detected |
| DataSSD drive  | only offered on the original machine                    |
| Features       | a checklist; type numbers to toggle, Enter to accept    |

The optional features are listed below. The desktop itself (Hyprland, the
shell, fonts, theming, screenshots and the login screen) is always installed.

| Feature        | What it adds                                              |
| -------------- | --------------------------------------------------------- |
| Virtualization | virt-manager/libvirt VMs and Waydroid (Android apps)      |
| Games          | Steam                                                     |
| Coding         | Neovim, Zed, language toolchains, Claude Code             |
| Apps           | browsers, Discord, LibreOffice, OBS, LocalSend, Obsidian… |
| Extras         | btop, cava, fastfetch, cmatrix and other terminal toys    |

Then it:

1. detects the boot mode: UEFI gets systemd-boot; legacy BIOS gets GRUB,
   after asking which disk to put it on;
2. creates `hosts/<hostname>/` with this machine's
   `hardware-configuration.nix`;
3. writes `hosts/<hostname>/settings.nix`, keeping your install's
   `stateVersion`;
4. stages everything with `git add -A` (flakes ignore untracked files);
5. shows a summary and, once you confirm, runs
   `nixos-rebuild switch` for you.

Options:

- `--demo` walks through every prompt and prints exactly what it _would_ do,
  including the `settings.nix` it would write, without touching a file or
  building anything. Try this first.
- `--yes` accepts every default without asking.
- `--no-switch` writes the configuration but skips the build.

Re-running the installer offers your previous choices as the defaults. You can
also flip a feature later by editing `features` in
`hosts/<hostname>/settings.nix` and rebuilding.

**Already set up a user and hostname while installing NixOS?** That's the
usual case. Run the installer while logged in as that user and press Enter at
the username and hostname prompts. The defaults are your current ones, so
nothing gets renamed. Your account keeps its password, home folder and files,
and nixcraft only takes over managing it.

> If you type a username that doesn't exist yet, NixOS creates it on switch.
> Give it a password with `sudo passwd <user>` and clone the repo into _its_
> home instead.

### 4. Reboot and log in

Pick Hyprland at the login screen. A few things to do once:

- **Git identity:** `modules/user/git/default.nix` holds the original author's
  name and email. Change them to yours.
- **Wallpapers** are read from `~/Pictures/wallpapers/<theme>/`, outside the
  repo. Add a folder per theme you use.
- **Tmux plugins** are ignored by Git. Install them in tmux with `prefix`, then `I`.
- **Monitors** start at their best mode, placed automatically. Change
  resolution, scale and mirroring in _Settings → Display_; that's saved per
  machine in `config/hypr/displays.lua`, which isn't tracked by Git.

### Doing it by hand

If you'd rather not run the script:

```bash
mkdir hosts/<hostname>
sudo nixos-generate-config --show-hardware-config \
  > hosts/<hostname>/hardware-configuration.nix
cp hosts/oneiros/settings.nix hosts/<hostname>/
$EDITOR hosts/<hostname>/settings.nix      # username, timezone, boot, toggles
git add -A
sudo nixos-rebuild switch --flake .#<hostname> \
  --option experimental-features "nix-command flakes"
```

In `settings.nix`, set `stateVersion` to the release you first installed (see
`/etc/nixos/configuration.nix`) and never bump it later. Set `boot.loader` to
`"grub"` with `boot.grubDevice` (e.g. `/dev/sda`) if the machine boots with
legacy BIOS rather than UEFI.

### Rebuilding and updating

Edits under `config/` take effect without a rebuild, since they're linked into
`~/.config`. Reload the app instead (`SUPER+R` reloads Hyprland and the shell).
After changing anything under `modules/` or `hosts/`:

```bash
sudo nixos-rebuild switch --flake ~/nixcraft#<hostname>
```

To update every input:

```bash
cd ~/nixcraft
nix flake update
sudo nixos-rebuild switch --flake .#<hostname>
```

### Troubleshooting

| Problem                                           | Fix                                                                                                   |
| ------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| `path ... does not exist` or a file is not found  | A new file isn't tracked. Run `git add -A`; flakes ignore untracked files.                            |
| `flake ... does not provide attribute ...#<host>` | No `hosts/<host>/settings.nix`: the folder name is the hostname after `#`.                            |
| `experimental feature 'flakes' is disabled`       | First build only: add `--option experimental-features "nix-command flakes"`.                          |
| Boot hangs waiting for a disk                     | `dataDrive = true` on a machine without that drive. Set it to `false` in its `settings.nix`.          |
| Black screen or no Hyprland                       | Check `nvidiaOptimus` in its `settings.nix`, and the GPU options in `modules/system/gpu`.             |
| Doesn't boot after switching                      | Wrong `boot.loader` for the firmware. Pick the previous generation at boot, then fix `settings.nix`.  |
| `~/.config/...` links are broken                  | The repo isn't at `/home/<username>/nixcraft`. Move it there and rebuild.                             |
| Undo a bad switch                                 | `sudo nixos-rebuild switch --rollback`, or pick an older generation at boot.                          |
