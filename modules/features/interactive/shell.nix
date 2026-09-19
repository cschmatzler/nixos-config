_:
with import ../../_lib/theme.nix; {
  den.aspects.shell.homeManager = {
    lib,
    pkgs,
    ...
  }: {
    home.packages = with pkgs; [
      devenv
      nano
    ];

    home.sessionVariables = {
      COLORTERM = "truecolor";
      COLORFGBG = "0;15";
      EDITOR = "nano";
      SHELL = "${pkgs.zsh}/bin/zsh";
      TERM_BACKGROUND = "light";
      VISUAL = "nano";
    };

    programs.direnv = {
      enable = true;
      enableZshIntegration = true;
    };

    programs.atuin = {
      enable = true;
      enableZshIntegration = true;
      flags = ["--disable-up-arrow"];
      settings = {
        style = "compact";
        inline_height = 0;
        show_help = false;
        show_tabs = false;
      };
    };

    programs.vivid = {
      enable = true;
      activeTheme = slug;
      enableBashIntegration = false;
      enableNushellIntegration = false;
      enableZshIntegration = true;
    };

    programs.zsh = {
      enable = true;
      autocd = true;
      defaultKeymap = "viins";
      enableCompletion = true;
      autosuggestion = {
        enable = true;
        highlight = "fg=${hex.muted}";
      };
      syntaxHighlighting = {
        enable = true;
        highlighters = ["brackets"];
        styles = {
          alias = "fg=${hex.iris}";
          builtin = "fg=${hex.pine}";
          command = "fg=${hex.pine}";
          comment = "fg=${hex.muted}";
          function = "fg=${hex.iris}";
          globbing = "fg=${hex.rose}";
          path = "fg=${hex.foam},underline";
          precommand = "fg=${hex.gold}";
          reserved-word = "fg=${hex.pine},bold";
          single-hyphen-option = "fg=${hex.foam}";
          double-hyphen-option = "fg=${hex.foam}";
          single-quoted-argument = "fg=${hex.gold}";
          double-quoted-argument = "fg=${hex.gold}";
          unknown-token = "fg=${hex.love}";
        };
      };
      envExtra =
        ''
          typeset -U path PATH
        ''
        + lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
          path=(
            "$HOME/.nix-profile/bin"
            /run/current-system/sw/bin
            $path
          )
        ''
        + lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
          path=(
            /run/wrappers/bin
            "$HOME/.nix-profile/bin"
            /nix/profile/bin
            "$HOME/.local/state/nix/profile/bin"
            "/etc/profiles/per-user/$USER/bin"
            /nix/var/nix/profiles/default/bin
            /run/current-system/sw/bin
            $path
          )
        ''
        + ''
          export PATH
        '';
      initContent = lib.mkAfter ''
        setopt interactive_comments no_beep
        KEYTIMEOUT=1

        for keymap in viins vicmd; do
          bindkey -M "$keymap" '^[[A' history-beginning-search-backward
          bindkey -M "$keymap" '^[[B' history-beginning-search-forward
          bindkey -M "$keymap" '^[OA' history-beginning-search-backward
          bindkey -M "$keymap" '^[OB' history-beginning-search-forward
        done
        unset keymap

        zstyle ':completion:*' menu select
        zstyle ':completion:*' list-colors ''${(s.:.)LS_COLORS}

        grt() {
          local root
          root="$(git rev-parse --show-toplevel 2>/dev/null)" || root="."
          cd "$root"
        }

        scratch() {
          local tmpfile
          tmpfile="$(mktemp)" || return 1
          command "''${EDITOR:-nano}" "$tmpfile"
        }

        trash() {
          if (( $# < 1 )); then
            print -u2 "Usage: trash <file>..."
            return 1
          fi

          local trash_dir
          if [[ "$OSTYPE" == darwin* ]]; then
            trash_dir="$HOME/.Trash"
          elif [[ -n "$XDG_DATA_HOME" ]]; then
            trash_dir="$XDG_DATA_HOME/Trash/files"
          else
            trash_dir="$HOME/.local/share/Trash/files"
          fi

          command mkdir -p "$trash_dir" || return 1

          local file basename dest
          for file in "$@"; do
            if [[ ! -e "$file" ]]; then
              print -u2 "Error: '$file' does not exist"
              continue
            fi

            basename="''${file:t}"
            dest="$trash_dir/$basename"

            if [[ -e "$dest" ]]; then
              dest="$trash_dir/$basename.$(date +%s)"
            fi

            command mv -v -- "$file" "$dest"
          done
        }
      '';
    };

    programs.starship = {
      enable = true;
      enableZshIntegration = true;
      settings = {
        format = "$directory$git_branch$git_status$git_state$git_commit$hostname$line_break$character";
        buf = {
          disabled = true;
        };
        character = {
          error_symbol = "[󰘧](bold ${hex.love})";
          success_symbol = "[󰘧](bold ${hex.pine})";
          vimcmd_symbol = "[󰘧](bold ${hex.pine})";
          vimcmd_replace_one_symbol = "[󰘧](bold ${hex.rose})";
          vimcmd_replace_symbol = "[󰘧](bold ${hex.rose})";
          vimcmd_visual_symbol = "[󰘧](bold ${hex.iris})";
        };
        directory = {
          truncate_to_repo = false;
        };
        git_branch = {
          disabled = false;
          symbol = " ";
          truncation_length = 18;
        };
        git_status = {
          disabled = false;
        };
        git_commit = {
          disabled = false;
        };
        git_state = {
          disabled = false;
        };
        lua = {
          symbol = " ";
        };
        package = {
          disabled = true;
        };
      };
    };
  };
}
