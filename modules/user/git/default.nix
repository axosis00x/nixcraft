{ config, lib, ... }:

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
        "github.com" = {
          Hostname = "github.com";
          User = "git";
          IdentityFile = "~/.ssh/github";
          IdentitiesOnly = true;
        };
        # Second account (dikchya355): use git@github-dikchya:owner/repo.git.
        "github-dikchya" = {
          Hostname = "github.com";
          User = "git";
          IdentityFile = "~/.ssh/github-dikchya";
          IdentitiesOnly = true;
        };
      };
    };

    services.ssh-agent.enable = true;
    programs.git = {
      enable = true;

      settings = {
        user.name = "axosis";
        user.email = "130370071+frgnc-subash@users.noreply.github.com";
        init.defaultBranch = "main";

        pull.rebase = true;
        push.autoSetupRemote = true;

        fetch.prune = true;

        core.editor = "zeditor";

        color.ui = "auto";

        alias = {
          st = "status";
          lg = "log --oneline --graph --decorate --all";
          co = "checkout";
          br = "branch";
          cm = "commit";

          # Switch the current repo between accounts: sets the commit
          # identity and points origin at that account's SSH host.
          as-dikchya = "!git config user.name dikchya355 && git config user.email 189239361+dikchya355@users.noreply.github.com && git remote set-url origin \"$(git remote get-url origin | sed -E 's#git@github(-dikchya)?(\\.com)?:#git@github-dikchya:#')\" && git whoami";
          as-axosis = "!git config --unset user.name; git config --unset user.email; git remote set-url origin \"$(git remote get-url origin | sed -E 's#git@github(-dikchya)?(\\.com)?:#git@github.com:#')\" && git whoami";
          whoami = "!echo \"$(git config user.name) <$(git config user.email)> -> $(git remote get-url origin 2>/dev/null)\"";
        };
      };

      # Repos under ~/Projects/thirdparty/dikchya commit as dikchya355 and
      # push with dikchya's SSH key (github.com URLs are rewritten to the
      # github-dikchya host), however they were cloned.
      includes = [
        {
          condition = "gitdir:~/Projects/thirdparty/dikchya/";
          contents = {
            user = {
              name = "dikchya355";
              email = "189239361+dikchya355@users.noreply.github.com";
            };
            url."git@github-dikchya:".insteadOf = [
              "git@github.com:"
              "https://github.com/"
            ];
          };
        }
      ];
    };
  };
}
