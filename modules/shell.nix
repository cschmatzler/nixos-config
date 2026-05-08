{...}: let
	local = import ./_lib/local.nix;
	theme = (import ./_lib/theme.nix).rosePineDawn;
	palette = theme.hex;
	color = builtins.replaceStrings ["#"] [""];
in {
	den.aspects.shell.homeManager = {
		lib,
		pkgs,
		...
	}: {
		home.packages = with pkgs; [
			openssl
			vivid
		];

		programs.fish = {
			enable = true;

			functions = {
				open_project = ''
					set -l base "$HOME/Projects"
					set -l choice (${pkgs.fd}/bin/fd -t d -d 1 -a . "$base/Personal" "$base/Work" 2>/dev/null | string replace "$base/" "" | ${pkgs.fzf}/bin/fzf --prompt "project > ")

					if test -n "$choice"
						cd "$base/$choice"
						commandline -f repaint
					end
				'';
			};

			shellInit =
				''
					set -gx COLORTERM truecolor
					set -gx COLORFGBG "15;0"
					set -gx TERM_BACKGROUND light
					set -gx EDITOR nvim
					set -gx LS_COLORS (${pkgs.vivid}/bin/vivid generate ${theme.slug})
				''
				+ lib.optionalString pkgs.stdenv.isDarwin ''
					fish_add_path --prepend "$HOME/.nix-profile/bin" /run/current-system/sw/bin
				'';

			interactiveShellInit = ''
				set fish_greeting
				fish_vi_key_bindings
				bind --mode insert \co open_project
				bind --mode default \co open_project

				set -g fish_color_normal ${color palette.text}
				set -g fish_color_command ${color palette.pine}
				set -g fish_color_keyword ${color palette.iris}
				set -g fish_color_quote ${color palette.gold}
				set -g fish_color_redirection ${color palette.subtle}
				set -g fish_color_end ${color palette.muted}
				set -g fish_color_error ${color palette.love}
				set -g fish_color_param ${color palette.rose}
				set -g fish_color_comment ${color palette.muted}
				set -g fish_color_match --background=${color palette.highlightHigh}
				set -g fish_color_selection --background=${color palette.highlightMed}
				set -g fish_color_search_match --background=${color palette.gold} ${color palette.base}
				set -g fish_color_operator ${color palette.subtle}
				set -g fish_color_escape ${color palette.foam}
				set -g fish_color_autosuggestion ${color palette.highlightHigh}
				set -g fish_color_valid_path ${color palette.iris}
				set -g fish_color_cwd ${color palette.iris}
				set -g fish_color_user ${color palette.rose}
				set -g fish_color_host ${color palette.pine}
				set -g fish_color_cancel ${color palette.love}
				set -g fish_pager_color_progress ${color palette.foam}
				set -g fish_pager_color_prefix ${color palette.gold} --bold
				set -g fish_pager_color_completion ${color palette.text}
				set -g fish_pager_color_description ${color palette.subtle}
			'';
		};

		programs.zsh = {
			enable = true;
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
