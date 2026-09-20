{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.userSettings.looks;
  mocu-xcursor = pkgs.callPackage ./mocu-xcursor.nix { };
in
{
  options.userSettings.looks = {
    enable = lib.mkEnableOption "system looks";
  };
  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      adw-gtk3
      papirus-icon-theme
      mocu-xcursor
      nerd-fonts.jetbrains-mono
      nerd-fonts.departure-mono
      nerd-fonts.geist-mono
      noto-fonts-color-emoji
      material-symbols
      inter
      mononoki
      iosevka
      monaspace
      corefonts
      inputs.apple-fonts.packages.${pkgs.stdenv.hostPlatform.system}.sf-pro
      inputs.apple-fonts.packages.${pkgs.stdenv.hostPlatform.system}.sf-mono
      inputs.apple-fonts.packages.${pkgs.stdenv.hostPlatform.system}.ny
      libsForQt5.qtstyleplugin-kvantum
      qt6Packages.qtstyleplugin-kvantum
    ];

    fonts.fontconfig.enable = true;

    home.pointerCursor = {
      enable = true;
      gtk.enable = true;
      x11.enable = true;
      package = mocu-xcursor;
      name = "Mocu-Black-Right";
      size = 24;
    };

    # Make Qt apps actually use Kvantum
    qt = {
      enable = true;
      platformTheme.name = "kvantum";
      style.name = "kvantum";
    };
    gtk = {
      enable = true;
      cursorTheme = {
        name = "Mocu-Black-Right";
        size = 24;
        package = mocu-xcursor;
      };
    };
    # Tell Kvantum which theme to load
    xdg.configFile."Kvantum/kvantum.kvconfig".text = ''
      [General]
      theme=KvMojave
    '';
  };
}
