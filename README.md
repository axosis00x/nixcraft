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

Your username, hostname and timezone, and the two hardware options that only
fit the original machine, all live in one file: [`settings.nix`](settings.nix).
The installer fills it in for you, so it works with any username and hostname.

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
| Full name      | your account's full name                                |
| Hostname       | the current hostname                                    |
| Timezone       | the system timezone                                     |
| NVIDIA Optimus | **yes** only if both Intel and NVIDIA GPUs are detected |
| DataSSD drive  | only offered on the original machine                    |

Then it:

1. creates `hosts/<hostname>/` from the `oneiros` example (keeping your
   install's `stateVersion`) and generates its `hardware-configuration.nix`;
2. writes `settings.nix`;
3. points the active-theme files at your home directory;
4. stages everything with `git add -A` (flakes ignore untracked files);
5. shows a summary and, once you confirm, runs
   `nixos-rebuild switch` for you.

Options: `--yes` accepts every default without asking, and `--no-switch`
prepares everything but skips the build.

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
- **Monitors:** `config/hypr/modules/monitors.lua` describes the original
  laptop panel. Other outputs fall back to their best mode automatically, and
  you can change resolution and scale in _Settings → Display_.

### Doing it by hand

If you'd rather not run the script:

```bash
cp -r hosts/oneiros hosts/<hostname>        # skip if your hostname is oneiros
sudo nixos-generate-config --show-hardware-config \
  > hosts/<hostname>/hardware-configuration.nix
$EDITOR settings.nix                        # username, hostname, timezone, toggles
git add -A
sudo nixos-rebuild switch --flake .#<hostname> \
  --option experimental-features "nix-command flakes"
```

Also set `system.stateVersion` in `hosts/<hostname>/configuration.nix` and
`home.stateVersion` in `hosts/<hostname>/home.nix` to the release you first
installed (see `/etc/nixos/configuration.nix`), and never bump them later.

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
| `flake ... does not provide attribute ...#<host>` | The `hostname` in `settings.nix` doesn't match the name after `#`, or `hosts/<hostname>/` is missing. |
| `experimental feature 'flakes' is disabled`       | First build only: add `--option experimental-features "nix-command flakes"`.                          |
| Boot hangs waiting for a disk                     | `dataDrive = true` on a machine without that drive. Set it to `false` in `settings.nix`.              |
| Black screen or no Hyprland                       | Check `nvidiaOptimus` in `settings.nix`, and the GPU options in `modules/system/gpu`.                 |
| `~/.config/...` links are broken                  | The repo isn't at `/home/<username>/nixcraft`. Move it there and rebuild.                             |
| Undo a bad switch                                 | `sudo nixos-rebuild switch --rollback`, or pick an older generation at boot.                          |
