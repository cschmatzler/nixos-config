_:
with (import ../../_lib/theme.nix).rosePineDawn; {
  den.aspects.shell.homeManager = {
    lib,
    pkgs,
    ...
  }: {
    home.packages = with pkgs; [
      devenv
      vivid
    ];

    home.sessionVariables = {
      COLORTERM = "truecolor";
      COLORFGBG = "0;15";
      TERM_BACKGROUND = "light";
    };

    xdg.configFile."fish/themes/${fishThemeName}.theme".source = "${pkgs.fetchFromGitHub {
      owner = "rose-pine";
      repo = "fish";
      rev = "127a990e5ad4688118c950123787fb0686afa4c8";
      hash = "sha256-3heI6nhItw5WfKGQT1FRQKfv+lONyn+DzwYjYqJjzLE=";
    }}/themes/${fishThemeName}.theme";

    programs.fish = {
      enable = true;
      shellInit =
        ''
          set -gx LS_COLORS (${pkgs.vivid}/bin/vivid generate ${slug})
          set -gx SHELL ${pkgs.fish}/bin/fish
        ''
        + lib.optionalString pkgs.stdenv.isDarwin ''
          fish_add_path --prepend "$HOME/.nix-profile/bin" /run/current-system/sw/bin
        ''
        + lib.optionalString pkgs.stdenv.isLinux ''
          fish_add_path --prepend \
            /run/wrappers/bin \
            "$HOME/.nix-profile/bin" \
            /nix/profile/bin \
            "$HOME/.local/state/nix/profile/bin" \
            "/etc/profiles/per-user/$USER/bin" \
            /nix/var/nix/profiles/default/bin \
            /run/current-system/sw/bin
        '';
      interactiveShellInit = ''
        set fish_greeting
        fish_vi_key_bindings
        fish_config theme choose "${fishThemeName}" >/dev/null
        devenv hook fish | source
      '';
      functions = {
        fish_mode_prompt = ''
          switch $fish_bind_mode
            case default
              set_color --bold ${builtins.replaceStrings ["#"] [""] hex.pine}
              echo -n "· "
              set_color normal
            case insert
              echo -n "· "
          end
        '';
        grt = ''
          cd (git rev-parse --show-toplevel; or echo ".")
        '';
        scratch = ''
          set -l tmpfile (mktemp)
          if set -q EDITOR
            $EDITOR $tmpfile
          else if command -v nvim &>/dev/null
            nvim $tmpfile
          else if command -v vim &>/dev/null
            vim $tmpfile
          else
            nano $tmpfile
          end
        '';
        trash = ''
          if test (count $argv) -lt 1
            echo "Usage: trash <file>..."
            return 1
          end

          set -l trash_dir
          if test (uname) = Darwin
            set trash_dir ~/.Trash
          else if test -n "$XDG_DATA_HOME"
            set trash_dir $XDG_DATA_HOME/Trash/files
          else
            set trash_dir ~/.local/share/Trash/files
          end

          if not test -d $trash_dir
            mkdir -p $trash_dir
          end

          for file in $argv
            if not test -e $file
              echo "Error: '$file' does not exist"
              continue
            end

            set -l basename (basename $file)
            set -l dest $trash_dir/$basename

            if test -e $dest
              set dest "$trash_dir/$basename."(date +%s)
            end

            mv -v $file $dest
          end
        '';
      };
    };

    programs.starship = {
      enable = true;
      enableFishIntegration = true;
      settings = {
        format = "$directory$git_branch$git_status$git_state$git_commit$hostname$line_break$character";
        buf = {
          disabled = true;
        };
        character = {
          error_symbol = "[󰘧](bold ${hex.love})";
          success_symbol = "[󰘧](bold ${hex.pine})";
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
