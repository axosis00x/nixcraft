# This machine's settings. Every folder in hosts/ is one machine, named after
# its hostname; flake.nix builds each as nixosConfigurations.<folder> and
# hands this file to every module as `settings`. ./install.sh writes it.
{
  # Login name and its home directory (/home/<username>). The repo must be
  # cloned to /home/<username>/nixcraft (config/ is linked from there).
  username = "axosis00x";
  fullName = "axosis incon";

  # Git commit identity (an empty string leaves it unset).
  git = {
    name = "axosis00x";
    email = "130370071+axosis00x@users.noreply.github.com";
  };

  # The hostname is this folder's name (hosts/<hostname>), also used as
  # the flake output: nixos-rebuild switch --flake ~/nixcraft#<hostname>
  timezone = "Asia/Kathmandu";

  # Release this machine was first installed with; never bump it.
  stateVersion = "26.05";

  # "systemd-boot" for UEFI (efiMount = the EFI partition's mount point),
  # "grub" for legacy BIOS (grubDevice = the boot disk, e.g. /dev/sda).
  boot = {
    loader = "systemd-boot";
    efiMount = "/boot";
    grubDevice = "";
  };

  # Hardware specific to the original machine; turn off elsewhere.
  # NVIDIA Optimus (Intel + NVIDIA laptop graphics): modules/system/gpu
  nvidiaOptimus = true;
  # Extra ext4 drive mounted by UUID at ~/DataSSD: modules/system/storage
  dataDrive = true;
  # Running inside a virtual machine (enables the guest clipboard agent).
  vm = false;

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
