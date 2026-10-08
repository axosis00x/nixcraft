{ pkgs, ... }:
{

  home.packages = with pkgs; [
    home-manager
  ];

  wayland.windowManager.hyprland.systemd.enable = false;

  home.username = "axosis00x";
  home.homeDirectory = "/home/axosis00x";

  userSettings.applications.enable = true;
  userSettings.utils.enable = true;
  userSettings.coding.enable = true;
  userSettings.git.enable = true;
  userSettings.shell.enable = true;
  userSettings.media.enable = true;
  userSettings.hyprland.enable = true;
  userSettings.games.enable = true;
  userSettings.looks.enable = true;
  userSettings.extra.enable = true;
  home.stateVersion = "26.05";
}
