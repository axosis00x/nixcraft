{ config, settings, ... }:

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
}
