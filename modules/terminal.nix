{...}: {
	den.aspects.terminal.darwin = {pkgs, ...}: {
		fonts.packages = [
			pkgs.nerd-fonts.iosevka
		];
	};

	den.aspects.terminal.homeManager = {
		pkgs,
		lib,
		...
	}: {
		xdg.configFile."ghostty/config".text = ''
			command = ${pkgs.nushell}/bin/nu
			theme = Rose Pine Dawn
			window-padding-x = 12
			window-padding-y = 3
			window-padding-balance = true
			font-family = Iosevka Nerd Font
			font-size = 17.5
			cursor-style = block
			mouse-hide-while-typing = true
			mouse-scroll-multiplier = 1.25
			shell-integration = none
			shell-integration-features = no-cursor
			clipboard-read = allow
			clipboard-write = allow
		'';

		programs.bat = {
			enable = true;
			config = {
				theme = "Rosé Pine Dawn";
				pager = "ov";
			};
			themes = {
				"Rosé Pine Dawn" = {
					src =
						pkgs.fetchFromGitHub {
							owner = "rose-pine";
							repo = "tm-theme";
							rev = "23bb25b9c421cdc9ea89ff3ad3825840cd19d65d";
							hash = "sha256-GUFdv5V5OZ2PG+gfsbiohMT23LWsrZda34ReHBr2Xy0=";
						};
					file = "dist/rose-pine-dawn.tmTheme";
				};
			};
		};

		programs.fzf = {
			enable = true;
		};

		home.sessionVariables = {
			FZF_DEFAULT_OPTS = ''
				--bind=alt-k:up,alt-j:down
				--expect=tab,enter
				--layout=reverse
				--delimiter='\t'
				--with-nth=1
				--preview-window='border-rounded' --prompt='  ' --marker=' ' --pointer=' '
				--separator='─' --scrollbar='┃' --layout='reverse'

				--color=bg+:#f2e9e1,bg:#faf4ed,spinner:#ea9d34,hl:#d7827e
				--color=fg:#797593,header:#286983,info:#56949f,pointer:#907aa9
				--color=marker:#b4637a,fg+:#575279,prompt:#797593,hl+:#d7827e
				--color=selected-bg:#f2e9e1
				--color=border:#dfdad9,label:#575279
			'';
		};

		programs.ripgrep = {
			enable = true;
			arguments = [
				"--max-columns=150"
				"--max-columns-preview"
				"--hidden"
				"--smart-case"
				"--colors=column:none"
				"--colors=column:fg:4"
				"--colors=column:style:underline"
				"--colors=line:none"
				"--colors=line:fg:4"
				"--colors=match:none"
				"--colors=match:bg:0"
				"--colors=match:fg:6"
				"--colors=path:none"
				"--colors=path:fg:14"
				"--colors=path:style:bold"
			];
		};

		programs.zoxide = {
			enable = true;
			enableNushellIntegration = true;
		};

		programs.yazi = {
			enable = true;
			enableNushellIntegration = true;
			shellWrapperName = "y";
			settings = {
				manager = {
					show_hidden = true;
					sort_by = "natural";
					sort_dir_first = true;
				};
			};
			theme = {
				tabs = {
					sep_inner = {
						open = "";
						close = "";
					};
					sep_outer = {
						open = "";
						close = "";
					};
				};
				indicator = {
					padding = {
						open = "";
						close = "";
					};
				};
				status = {
					sep_left = {
						open = "";
						close = "";
					};
					sep_right = {
						open = "";
						close = "";
					};
				};
			};
		};

		home.packages = with pkgs;
			[
				dust
				fastfetch
				fd
				glow
				htop
				jq
				killall
				lsof
				ouch
				ov
				sd
				tree
				tuicr
			]
			++ lib.optionals stdenv.isLinux [
				ghostty.terminfo
			];
	};
}
