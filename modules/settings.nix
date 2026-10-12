# What a host's settings.nix (hosts/<hostname>/settings.nix) may contain.
# flake.nix checks every host's file against these options before building
# anything, so a typo or a wrong type stops with a clear message pointing at
# that file, and whatever is left out gets the default below. Modules then
# read the checked result as `settings`.
{ config, lib, ... }:
let
  inherit (lib) mkOption types;
  flag =
    description:
    mkOption {
      type = types.bool;
      default = false;
      inherit description;
    };
in
{
  options = {
    hostname = mkOption {
      type = types.str;
      internal = true;
      description = "This host's folder name in hosts/ (filled in by flake.nix).";
    };
    system = mkOption {
      type = types.str;
      default = "x86_64-linux";
      description = "Platform to build for.";
    };

    username = mkOption {
      type = types.strMatching "[a-z_][a-z0-9_-]*";
      description = "Login name. Its home directory is /home/<username>.";
    };
    fullName = mkOption {
      type = types.str;
      default = config.username;
      description = "Display name of the account.";
    };
    repoPath = mkOption {
      type = types.str;
      default = "/home/${config.username}/nixcraft";
      description = "Where this repo is cloned; config/ is linked into ~/.config from here.";
    };

    git = {
      name = mkOption {
        type = types.str;
        default = "";
        description = "Git commit name (empty leaves it unset).";
      };
      email = mkOption {
        type = types.str;
        default = "";
        description = "Git commit email (empty leaves it unset).";
      };
    };

    timezone = mkOption {
      type = types.str;
      default = "UTC";
      description = "Time zone, e.g. Asia/Kathmandu.";
    };
    stateVersion = mkOption {
      type = types.str;
      description = "NixOS release this machine was first installed with; never bump it.";
    };

    boot = {
      loader = mkOption {
        type = types.enum [
          "systemd-boot"
          "grub"
        ];
        default = "systemd-boot";
        description = "systemd-boot for UEFI, grub for legacy BIOS.";
      };
      efiMount = mkOption {
        type = types.str;
        default = "/boot";
        description = "Mount point of the EFI partition (systemd-boot).";
      };
      grubDevice = mkOption {
        type = types.str;
        default = "";
        description = "Disk to install GRUB on, e.g. /dev/sda (required with grub).";
      };
    };

    nvidiaOptimus = flag "NVIDIA Optimus (Intel + NVIDIA laptop graphics): modules/system/gpu.";
    dataDrive = flag "The original machine's extra ext4 drive at ~/DataSSD: modules/system/storage.";
    vm = flag "Running inside a virtual machine (guest clipboard and QEMU agents).";

    features = {
      virtualization = flag "virt-manager/libvirt VMs and Waydroid (Android apps).";
      games = flag "Steam.";
      coding = flag "Editors (Neovim, Zed), language toolchains, Claude Code.";
      apps = flag "Browsers, Discord, LibreOffice, OBS, LocalSend, Obsidian…";
      extras = flag "Terminal toys and monitors (btop, cava, fastfetch, cmatrix…).";
    };
  };
}
