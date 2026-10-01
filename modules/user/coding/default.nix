{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.userSettings.coding;
in
{
  options.userSettings.coding = {
    enable = lib.mkEnableOption "coding";
  };
  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [

      # editors
      vim
      neovim
      zed-editor
      claude-code

      # languages & runtimes
      jdk21
      nodejs_24
      bun
      python3
      maven

      eww
      quickshell

      rustup
      clang-tools
      gcc
      cmake
      nixd
      nil
      pkgs.go
      pkgs.gopls
      pkgs.gotools
      uv
      qt6.qtdeclarative

      prettierd
      prettier
      google-java-format
      ruff
      shfmt
      stylua
      taplo
    ];
  };
}
