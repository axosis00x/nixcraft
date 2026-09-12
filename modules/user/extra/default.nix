# modules/user/extra/default.nix
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.userSettings.extra;
in {
  options.userSettings.extra = {
    enable = lib.mkEnableOption "extra utilities";
  };
  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      asciiquarium-transparent
      btop
      cava
      cmatrix
      fortune
      toilet
      lolcat
      cowsay
      fastfetch
      htop
      pokeget-rs
      pipes-rs
      nitch
      peaclock
      cbonsai
      inputs.momoi-say.packages.${pkgs.stdenv.hostPlatform.system}.momoisay
    ];
  };
}
