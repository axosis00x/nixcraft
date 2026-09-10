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

This configuration is currently for the `oneiros` host and the `axosis`
user. It contains machine-specific hardware, user, display, and theme
settings. Change those values before using it on another machine.

1. Install NixOS normally, boot into the new system, and connect to the
   internet.

2. Clone this repository into the target user's home directory:

   ```bash
   git clone https://github.com/frgnc-subash/nixcraft /home/axosis/nixcraft
   cd /home/axosis/nixcraft
   ```

3. Generate the new machine's hardware configuration and replace
   `hosts/oneiros/hardware-configuration.nix` with its output:

   ```bash
   sudo nixos-generate-config --show-hardware-config \
     > hosts/oneiros/hardware-configuration.nix
   ```

4. Review `hosts/oneiros/configuration.nix`. At minimum, update the hostname,
   user name, timezone, disk-related settings, and any GPU-specific options.
   If you change the user name, also update `hosts/oneiros/home.nix` and the
   paths in `modules/user/default.nix` that reference `~/nixcraft`.

5. Ensure all files needed by the flake are tracked, then build the system:

   ```bash
   git add -A
   sudo nixos-rebuild switch --flake /home/axosis/nixcraft#oneiros
   ```

6. Log out and back in. Home Manager links the editable application configs
   from `config/` into `~/.config`, so edits to files such as
   `config/hypr`, `config/nvim`, `config/quickshell`, and `config/themes` take
   effect directly. Reload or restart the relevant application after editing.

7. Tmux plugins are intentionally ignored by Git. After opening tmux, install
   them with the TPM install shortcut: `prefix` then `I`.
