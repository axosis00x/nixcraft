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

    # Stock Fusion with just the palette overridden per theme; the qt5ct/qt6ct
    # configs are written at runtime by config/quickshell/scripts/apply-qt.sh
    # (so they're deliberately not managed here — they must stay writable).
    qt = {
      enable = true;
      platformTheme.name = "qtct";
    };
    gtk = {
      enable = true;
      cursorTheme = {
        name = "Mocu-Black-Right";
        size = 24;
        package = mocu-xcursor;
      };
    };
  };
}
