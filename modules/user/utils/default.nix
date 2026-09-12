{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.userSettings.utils;
in
{
  options.userSettings.utils = {
    enable = lib.mkEnableOption "utils utilities";
  };
  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      wget
      curl
      glib
      polkit_gnome
      gsettings-desktop-schemas
      vips
      util-linux
      libsecret
    ];
  };
}
