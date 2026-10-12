{
  config,
  lib,
  settings,
  ...
}:

let
  cfg = config.userSettings.git;
in
{
  options.userSettings.git = {
    enable = lib.mkEnableOption "git configuration";
  };

  config = lib.mkIf cfg.enable {
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;

      settings = {
        "*" = {
          AddKeysToAgent = "yes";
        };
      };
    };

    services.ssh-agent.enable = true;
    programs.git = {
      enable = true;

      settings = {
        # Commit identity for this machine (hosts/<hostname>/settings.nix,
        # asked by install.sh). Left unset when empty, so git prompts.
        user = lib.filterAttrs (_: v: v != "") {
          name = settings.git.name or "";
          email = settings.git.email or "";
        };
        init.defaultBranch = "main";

        pull.rebase = true;
        push.autoSetupRemote = true;

        fetch.prune = true;

        # Zed comes with the coding feature; nano is always there.
        core.editor = if settings.features.coding then "zeditor" else "nano";

        color.ui = "auto";

        alias = {
          st = "status";
          lg = "log --oneline --graph --decorate --all";
          co = "checkout";
          br = "branch";
          cm = "commit";
          whoami = "!echo \"$(git config user.name) <$(git config user.email)> -> $(git remote get-url origin 2>/dev/null)\"";
        };
      };
    };
  };
}
