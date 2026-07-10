_: let
  theme = (import ./_lib/theme.nix).catppuccinLatte;
  palette = theme.hex;
  fishPromptColor = builtins.replaceStrings ["#"] [""] palette.pine;
in {
  den.aspects.shell.homeManager = {
    lib,
    pkgs,
    ...
  }: let
    fishThemeSrc = pkgs.fetchFromGitHub {
      owner = "catppuccin";
      repo = "fish";
      rev = "5fc5ae9c2ec22eb376cb03ce76f0d262a38960f3";
      hash = "sha256-3KNWYXfOMzZovdjwjBpjSH8cVlD4CO2QmQcCyQE4Dac=";
    };
  in {
    home.packages = with pkgs; [
      devenv
      vivid
    ];

    home.sessionVariables = {
      COLORTERM = "truecolor";
      COLORFGBG = "0;15";
      TERM_BACKGROUND = "light";
    };

    xdg.configFile."fish/themes/${theme.fishThemeName}.theme".source = "${fishThemeSrc}/themes/static/${theme.fishThemeName}.theme";

    programs.fish = {
      enable = true;
      shellInit =
        ''
          set -gx LS_COLORS (${pkgs.vivid}/bin/vivid generate ${theme.slug})
          set -gx SHELL ${pkgs.fish}/bin/fish
        ''
        + lib.optionalString pkgs.stdenv.isDarwin ''
          fish_add_path --prepend "$HOME/.nix-profile/bin" /run/current-system/sw/bin
        '';
      interactiveShellInit = ''
        set fish_greeting
        fish_vi_key_bindings
        fish_config theme choose "${theme.fishThemeName}" >/dev/null
        devenv hook fish | source
      '';
      functions = {
        fish_mode_prompt = ''
          switch $fish_bind_mode
            case default
              set_color --bold ${fishPromptColor}
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
          error_symbol = "[󰘧](bold red)";
          success_symbol = "[󰘧](bold green)";
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
