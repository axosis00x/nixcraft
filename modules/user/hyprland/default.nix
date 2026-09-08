{
  config,
  lib,
  pkgs,
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
    home.packages = (with pkgs; [
      brightnessctl
      kitty
      hyprsunset
      cliphist
      wl-clipboard
      grimblast
      playerctl
      polkit_gnome
      awww
      wiremix
      grim
      slurp
      hyprpicker
      libnotify
      hyprshade
      zenity
      wallust
      matugen
    ]) ++ [
      (pkgs.callPackage ./hyprglass.nix { })
    ];
    xdg.portal = {
      enable = true;
      extraPortals = with pkgs; [
        xdg-desktop-portal-hyprland
        xdg-desktop-portal-gtk
      ];
      configPackages = [ pkgs.hyprland ];
    };
    systemd.user.services.polkit-gnome-authentication-agent-1 = {
      Unit.Description = "Polkit GNOME Authentication Agent";
      Unit.After = [ "graphical-session.target" ];
      Install.WantedBy = [ "graphical-session.target" ];
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
        Restart = "on-failure";
      };
    };
  };
}
