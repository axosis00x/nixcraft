# Who and what this system is for. flake.nix reads this and hands it to
# every module as `settings`; ./install.sh writes it for a new machine.
{
  # Login name and its home directory (/home/<username>). The repo must be
  # cloned to /home/<username>/nixcraft (config/ is linked from there).
  username = "axosis00x";
  fullName = "axosis incon";

  # Also names the host folder (hosts/<hostname>) and the flake output
  # (nixos-rebuild switch --flake ~/nixcraft#<hostname>).
  hostname = "oneiros";
  timezone = "Asia/Kathmandu";

  # Hardware specific to the original machine; turn off elsewhere.
  # NVIDIA Optimus (Intel + NVIDIA laptop graphics): modules/system/gpu
  nvidiaOptimus = true;
  # Extra ext4 drive mounted by UUID at ~/DataSSD: modules/system/storage
  dataDrive = true;

  # Optional parts; the desktop itself (Hyprland, shell, fonts, theming,
  # screenshots, login screen) is always installed.
  features = {
    virtualization = true; # virt-manager/libvirt and Waydroid (Android apps)
    games = true; # Steam
    coding = true; # editors (Neovim, Zed), language toolchains, Claude Code
    apps = true; # browsers, Discord, LibreOffice, OBS, LocalSend, Obsidian…
    extras = true; # terminal toys and monitors (btop, cava, fastfetch, cmatrix…)
  };
}
