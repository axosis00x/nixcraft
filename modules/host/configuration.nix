{
  lib,
  pkgs,
  settings,
  ...
}:
{
  options.systemSettings = {
    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Users to configure via home-manager.";
    };
  };
  imports = [
    ../system/services
    ../system/gpu
    ../system/storage
    ../system/virtualization
    ../system/sddm
  ];
  config = {
    boot.kernelPackages = pkgs.linuxPackages_latest;

    systemSettings.users = [ settings.username ];
    systemSettings.services.enable = true;
    systemSettings.gpu.enable = settings.nvidiaOptimus;
    systemSettings.storage.enable = settings.dataDrive;
    systemSettings.virtualization.enable = settings.features.virtualization;
    systemSettings.sddm.enable = true;

    services.journald.settings.Journal.Storage = "persistent";
    services.flatpak.enable = true;

    services.gnome.gnome-keyring.enable = true;
    services.displayManager.ly.enable = false;
    security.pam.services.ly.enableGnomeKeyring = true;
    security.polkit.enable = true;

    # UEFI machines boot with systemd-boot, legacy BIOS ones with GRUB on
    # the disk in settings.boot.grubDevice (install.sh detects both).
    boot.loader =
      if settings.boot.loader == "grub" then
        {
          grub.enable = true;
          grub.device = settings.boot.grubDevice;
        }
      else
        {
          systemd-boot.enable = true;
          efi.canTouchEfiVariables = true;
          efi.efiSysMountPoint = settings.boot.efiMount;
        };

    # Running inside a VM: share the clipboard and resize with the host's
    # viewer (SPICE agent; Hyprland starts its session half, see
    # hypr/modules/autostarts.lua) and let the host shut it down cleanly.
    services.spice-vdagentd.enable = settings.vm or false;
    services.qemuGuest.enable = settings.vm or false;
    environment.systemPackages = lib.optional (settings.vm or false) pkgs.spice-vdagent;

    networking.hostName = settings.hostname;
    networking.networkmanager.enable = true;
    time.timeZone = settings.timezone;
    # Qt only looks for tzdata in /usr/share/zoneinfo (or /usr/lib), which
    # NixOS doesn't have; without this Qt apps such as Quickshell warn
    # "Unable to determine system time zone".
    systemd.tmpfiles.rules = [ "L+ /usr/share/zoneinfo - - - - /etc/zoneinfo" ];
    i18n.defaultLocale = "en_US.UTF-8";
    services.xserver.xkb = {
      layout = "us";
      variant = "";
    };

    users.users.${settings.username} = {
      # No fixed uid: an account that already exists keeps its own (NixOS
      # remembers assigned uids), so installing over a set-up user is safe.
      isNormalUser = true;
      description = settings.fullName;
      extraGroups = [
        "networkmanager"
        "wheel"
        "input"
      ];
      shell = pkgs.zsh;
    };

    nixpkgs.config = {
      allowUnfree = true;
      permittedInsecurePackages = [
        "pnpm-10.29.2"
        "electron-40.10.5"
      ];
    };

    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];

    nix.settings.auto-optimise-store = true;

    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
      withUWSM = true;
    };

    programs.zsh.enable = true;
    programs.dconf.enable = true;
    system.stateVersion = settings.stateVersion;
    programs.nix-ld.enable = true;
  };
}
