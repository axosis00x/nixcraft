{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.userSettings.wayclick;
  # evdev and pygame-ce come prebuilt from nixpkgs, so wayclick works on the
  # first ALT+V of a fresh install instead of needing a build in a terminal.
  python = pkgs.python3.withPackages (ps: [
    ps.evdev
    ps.pygame-ce
  ]);
in
{
  options.userSettings.wayclick = {
    enable = lib.mkEnableOption "wayclick keyboard sounds";
  };
  config = lib.mkIf cfg.enable {
    # config/wayclick/scripts/wayclick.sh runs its engine with this.
    home.packages = [
      (pkgs.writeShellScriptBin "wayclick-python" ''exec ${python}/bin/python "$@"'')
    ];
  };
}
