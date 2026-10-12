# Home Manager extras for this machine only (optional: any hosts/<hostname>/
# can have one). Here: axosis00x's SSH keys and the second GitHub account.
{ ... }:
{
  programs.ssh.settings = {
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

  programs.git = {
    settings.alias = {
      # Switch the current repo between accounts: sets the commit
      # identity and points origin at that account's SSH host.
      as-dikchya = "!git config user.name dikchya355 && git config user.email 189239361+dikchya355@users.noreply.github.com && git remote set-url origin \"$(git remote get-url origin | sed -E 's#git@github(-dikchya)?(\\.com)?:#git@github-dikchya:#')\" && git whoami";
      as-axosis = "!git config --unset user.name; git config --unset user.email; git remote set-url origin \"$(git remote get-url origin | sed -E 's#git@github(-dikchya)?(\\.com)?:#git@github.com:#')\" && git whoami";
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
}
