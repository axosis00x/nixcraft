{ pkgs, settings, ... }:
{

  home.packages = with pkgs; [
    home-manager
  ];

  wayland.windowManager.hyprland.systemd.enable = false;

  userSettings.applications.enable = settings.features.apps;
  userSettings.utils.enable = true;
  userSettings.coding.enable = settings.features.coding;
  userSettings.git.enable = true;
  userSettings.shell.enable = true;
  userSettings.media.enable = true;
  userSettings.hyprland.enable = true;
  userSettings.games.enable = settings.features.games;
  userSettings.looks.enable = true;
  userSettings.extra.enable = settings.features.extras;
  userSettings.wayclick.enable = true;
  home.stateVersion = settings.stateVersion;
}
