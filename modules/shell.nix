{...}: let
	local = import ./_lib/local.nix;
	theme = (import ./_lib/theme.nix).rosePineDawn;
	palette = theme.hex;
	pineFish = builtins.replaceStrings ["#"] [""] palette.pine;
in {
	den.aspects.shell.homeManager = {
		lib,
		pkgs,
		...
	}: let
		rosePineFish =
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
			COLORFGBG = "15;0";
			TERM_BACKGROUND = "light";
			EDITOR = "nvim";
		};

		xdg.configFile."fish/themes/Rosé Pine Dawn.theme".source = "${rosePineFish}/themes/Rosé Pine Dawn.theme";

		programs.fish = {
			enable = true;
			shellInit =
				''
					set -gx LS_COLORS (${pkgs.vivid}/bin/vivid generate ${theme.slug})
				''
				+ lib.optionalString pkgs.stdenv.isDarwin ''
					fish_add_path --prepend "$HOME/.nix-profile/bin" /run/current-system/sw/bin
				'';
			interactiveShellInit = ''
				set fish_greeting
				fish_vi_key_bindings
				fish_config theme choose "Rosé Pine Dawn" >/dev/null
				devenv hook fish | source
			'';
			functions.fish_mode_prompt = ''
				switch $fish_bind_mode
					case default
						set_color --bold ${pineFish}
						echo -n "· "
						set_color normal
					case insert
						echo -n "· "
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
