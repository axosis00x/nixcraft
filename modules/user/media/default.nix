{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.userSettings.media;
in
{
 imports = [
    ./mpv.nix
  ];
  options = {
    userSettings.media = {
      enable = lib.mkEnableOption "Enable media playback apps";
    };
  };
  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      ffmpeg
      tesseract
      swappy
      pulseaudio
      loupe
      satty
      wf-recorder
    ];
  };
}
