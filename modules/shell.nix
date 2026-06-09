{...}: let
	local = import ./_lib/local.nix;
	theme = (import ./_lib/theme.nix).rosePineDawn;
	palette = theme.hex;
	fishPromptColor = builtins.replaceStrings ["#"] [""] palette.pine;
in {
	den.aspects.shell.homeManager = {
		lib,
		pkgs,
		...
	}: let
		fishThemeSrc =
			pkgs.fetchFromGitHub {
				owner = "rose-pine";
				repo = "fish";
				rev = "127a990e5ad4688118c950123787fb0686afa4c8";
				hash = "sha256-3heI6nhItw5WfKGQT1FRQKfv+lONyn+DzwYjYqJjzLE=";
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
			EDITOR = "nvim";
			MANPAGER = "nvim +Man!";
		};

		xdg.configFile."fish/themes/${theme.fishThemeName}.theme".source = "${fishThemeSrc}/themes/${theme.fishThemeName}.theme";

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
			functions.fish_mode_prompt = ''
				switch $fish_bind_mode
					case default
						set_color --bold ${fishPromptColor}
						echo -n "· "
						set_color normal
					case insert
						echo -n "· "
				end
			'';
			functions.fvim = ''
				if test (count $argv) -eq 0
					fd -H -t f | fzf --header "Open File in Vim" --preview "cat {}" | xargs nvim
				else
					set -l query (string join " " $argv)
					fd -H -t f | fzf --header "Open File in Vim" --preview "cat {}" -q "$query" | xargs nvim
				end
			'';
			functions.grt = ''
				cd (git rev-parse --show-toplevel; or echo ".")
			'';
			functions.scratch = ''
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
			functions.trash = ''
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

		programs.starship = {
			enable = true;
			enableFishIntegration = true;
			settings = {
				format = "$directory\${custom.scm}$hostname$line_break$character";
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
					disabled = true;
					symbol = " ";
					truncation_length = 18;
				};
				git_status = {
					disabled = true;
				};
				git_commit = {
					disabled = true;
				};
				git_state = {
					disabled = true;
				};
				custom.scm = {
					when = "jj-starship detect";
					shell = ["jj-starship" "--strip-bookmark-prefix" "${local.user.name}/" "--truncate-name" "20" "--bookmarks-display-limit" "1"];
					format = "$output ";
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
