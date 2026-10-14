{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.userSettings.hyprland;
in
{
  options.userSettings.hyprland = {
    enable = lib.mkEnableOption "Hyprland window manager";
  };
  config = lib.mkIf cfg.enable {
    home.packages =
      (with pkgs; [
        brightnessctl
        kitty
        hyprsunset
        cliphist
        wl-clipboard
        grimblast
        playerctl
        # The shell's audio visualizers (bar and desktop widget).
        cava
        awww
        wiremix
        grim
        slurp
        # The desktop shell (bar, launcher, panels: config/quickshell).
        quickshell
        hyprpicker
        libnotify
        hyprshade
        zenity
        matugen
        rembg
      ])
      ++ [
        (pkgs.callPackage ./hyprglass.nix { })
        inputs.hyprmod.packages.${pkgs.stdenv.hostPlatform.system}.default
      ];
    xdg.portal = {
      enable = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-hyprland
        xdg-desktop-portal-gtk
      ];
      configPackages = [ pkgs.hyprland ];
    };
    # No separate polkit agent: the Quickshell shell is the agent
    # (config/quickshell/modules/polkit), and polkitd allows only one.
  };
}
