{
  config,
  lib,
  pkgs,
  settings,
  ...
}:
let
  cfg = config.userSettings.shell;
in
{
  config = lib.mkIf cfg.enable {
    programs.zsh = {
      enable = true;
      enableCompletion = true;

      autosuggestion = {
        enable = true;
        strategy = [
          "history"
          "completion"
        ];
        highlight = "fg=8";
      };

      history = {
        size = 5000;
        save = 5000;
        path = "${config.home.homeDirectory}/.zsh_history";
        append = true;
        share = true;
        ignoreSpace = true;
        ignoreAllDups = true;
        ignoreDups = true;
        findNoDups = true;
        saveNoDups = true;
      };

      shellAliases = {
        # Pin the newest Helium first (keeps the current one if offline), then rebuild.
        build = "${settings.repoPath}/modules/user/applications/update-helium.sh; sudo nixos-rebuild switch --flake ${settings.repoPath}";
        clean = "sudo nix-collect-garbage -d";
        ping = "ping -c 5";
        zed = "zeditor";
        topdf = "libreoffice --headless --convert-to pdf 2>/dev/null";
        todocx = "libreoffice --headless --convert-to docx 2>/dev/null";
        ls = "eza --icons";
        cat = "bat --paging=never --style=plain";
        ll = "eza -lh --icons --git";
        la = "eza -lah --color=always --group-directories-first";
        lah = "eza -lah --icons --group-directories-first";
        "l." = ''eza -la --icons | grep "^\."'';
        ".." = "cd ..";
        rm = "rm -i";
        lt = "eza --tree -L 2 --icons";
        ld = "eza -lD --icons";
        tm = "new_tmux";
        tree = "eza --tree --icons";
        tl = "tmux list-sessions";
        tk = "tmux kill-server";
        ta = "tmux a";
        asciiquarium = "asciiquarium --transparent";
      };

      initContent = ''
        bindkey -e
        bindkey '^p' history-search-backward
        bindkey '^n' history-search-forward

        export PATH=$HOME/.config/quickshell/scripts:$PATH
        export TERMINAL='kitty'
        export EDITOR='nvim'
        export VISUAL='nvim'

        export PATH="$HOME/.local/bin:$PATH"
        export XDG_CONFIG_HOME=~/.config/
        export XDG_CACHE_HOME="$HOME/.cache"
        export XDG_DATA_HOME="$HOME/.local/share"
        export XDG_STATE_HOME="$HOME/.local/state"
        export PATH=$PATH:~/.spicetify
        export GPG_TTY=$(tty)

        new_tmux() {
          session_dir=$(zoxide query --list | fzf --preview 'ls -la {}') || return
          session_name=$(basename "$session_dir")
          if tmux has-session -t "$session_name" 2>/dev/null; then
            if [ -n "$TMUX" ]; then
              tmux switch-client -t "$session_name"
            else
              tmux attach-session -t "$session_name"
            fi
          else
            if [ -n "$TMUX" ]; then
              tmux new-session -d -c "$session_dir" -s "$session_name"
              tmux switch-client -t "$session_name"
            else
              tmux new-session -c "$session_dir" -s "$session_name"
            fi
          fi
        }


        zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
        zstyle ':completion:*' list-colors "''${(s.:.)LS_COLORS}"
        zstyle ':completion:*' menu select
        zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
        zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'

        eval "$(starship init zsh)"
        source ${pkgs.zsh-fzf-tab}/share/fzf-tab/fzf-tab.plugin.zsh
        source ${pkgs.zsh-fast-syntax-highlighting}/share/zsh/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh
      '';
    };

    programs.fzf = {
      enable = true;
      enableZshIntegration = true;
    };

    programs.zoxide = {
      enable = true;
      enableZshIntegration = true;
      options = [
        "--cmd"
        "cd"
      ];
    };
  };
}
