{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.userSettings.shell;
in
{
  imports = [
    ./zsh.nix
    ./starship.nix
  ];

  options = {
    userSettings.shell = {
      enable = lib.mkEnableOption "shell";
    };
  };
  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      zsh-autosuggestions
      zsh-fast-syntax-highlighting
      fzf
      zsh-forgit
      zsh-fzf-history-search
      zsh-fzf-tab
      zoxide
      eza
      dust
      bat
      tree
      tmux
      ripgrep
      yazi
      herdr
      fetch
    ];
  };
}
