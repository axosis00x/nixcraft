{
  config,
  lib,
  pkgs,
  settings,
  ...
}:

{
  imports = [
    ./hyprland
    ./coding
    ./git
    ./media
    ./games
    ./looks
    ./shell
    ./utils
    ./applications
    ./extra
    ./wayclick
  ];

  xdg.configFile = {
    btop.source = config.lib.file.mkOutOfStoreSymlink "${settings.repoPath}/config/btop";
    cava.source = config.lib.file.mkOutOfStoreSymlink "${settings.repoPath}/config/cava";
    eww.source = config.lib.file.mkOutOfStoreSymlink "${settings.repoPath}/config/eww";
    fastfetch.source = config.lib.file.mkOutOfStoreSymlink "${settings.repoPath}/config/fastfetch";
    hypr.source = config.lib.file.mkOutOfStoreSymlink "${settings.repoPath}/config/hypr";
    kitty.source = config.lib.file.mkOutOfStoreSymlink "${settings.repoPath}/config/kitty";
    nvim.source = config.lib.file.mkOutOfStoreSymlink "${settings.repoPath}/config/nvim";
    quickshell.source = config.lib.file.mkOutOfStoreSymlink "${settings.repoPath}/config/quickshell";
    themes.source = config.lib.file.mkOutOfStoreSymlink "${settings.repoPath}/config/themes";
    tmux.source = config.lib.file.mkOutOfStoreSymlink "${settings.repoPath}/config/tmux";
    wayclick.source = config.lib.file.mkOutOfStoreSymlink "${settings.repoPath}/config/wayclick";
    yazi.source = config.lib.file.mkOutOfStoreSymlink "${settings.repoPath}/config/yazi";
    zed.source = config.lib.file.mkOutOfStoreSymlink "${settings.repoPath}/config/zed";
  };

  # Machine-local state that git doesn't track (see .gitignore): on a fresh
  # install, point every app at the default theme and give HyprMod an empty
  # file to write into. Does nothing once they exist.
  home.activation.nixcraftState =
    let
      repo = settings.repoPath;
    in
    lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      if [ -f ${repo}/config/quickshell/scripts/apply-theme.sh ]; then
        run ${pkgs.bash}/bin/bash ${repo}/config/quickshell/scripts/apply-theme.sh --init ||
          echo "nixcraft: couldn't set up the default theme" >&2
        [ -e ${repo}/config/hypr/hyprland-gui.lua ] || run touch ${repo}/config/hypr/hyprland-gui.lua
      else
        echo "nixcraft: no repo at ${repo}; set repoPath in this host's settings.nix" >&2
      fi
    '';
}
