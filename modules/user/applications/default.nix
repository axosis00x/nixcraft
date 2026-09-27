{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.userSettings.applications;
in
{
  options = {
    userSettings.applications = {
      enable = lib.mkEnableOption "Enable applications apps";
    };
  };
  imports = [
    ./spicetify.nix
    inputs.zen-browser.homeModules.twilight
  ];
  config = lib.mkIf cfg.enable {
    programs.zen-browser.enable = true;

    home.packages = with pkgs; [
      vesktop
      switcheroo
      localsend
      obs-studio
      mission-center
      proton-authenticator
      proton-vpn
      wireguard-tools
      brave
      libreoffice-stable
      errands
      zathura
      zathuraPkgs.zathura_pdf_poppler
      obsidian
      blanket
      nautilus
      nwg-look
      gnome-disk-utility
      zotero
    ];
  };
}
