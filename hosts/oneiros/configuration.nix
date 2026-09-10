{
  lib,
  pkgs,
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
    ./hardware-configuration.nix
    ../../modules/system/services
    ../../modules/system/gpu
    ../../modules/system/storage
    ../../modules/system/virtualization
    ../../modules/system/sddm
  ];
  config = {
    boot.kernelPackages = pkgs.linuxPackages_latest;

    systemSettings.users = [ "axosis" ];
    systemSettings.services.enable = true;
    systemSettings.gpu.enable = true;
    systemSettings.storage.enable = true;
    systemSettings.virtualization.enable = true;
    systemSettings.sddm.enable = true;

    services.journald.settings.Journal.Storage = "persistent";
    services.flatpak.enable = true;

    services.gnome.gnome-keyring.enable = true;
    services.displayManager.ly.enable = false;
    security.pam.services.ly.enableGnomeKeyring = true;
    security.polkit.enable = true;

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    boot.loader.efi.efiSysMountPoint = "/boot";

    networking.hostName = "oneiros";
    networking.networkmanager.enable = true;
    time.timeZone = "Asia/Kathmandu";
    i18n.defaultLocale = "en_US.UTF-8";
    services.xserver.xkb = {
      layout = "us";
      variant = "";
    };

    users.users.axosis = {
      isNormalUser = true;
      description = "axosis incon";
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
    system.stateVersion = "26.05";
    programs.nix-ld.enable = true;
  };
}
