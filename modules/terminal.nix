{...}: let
	theme = (import ./_lib/theme.nix).rosePineDawn;
	palette = theme.hex;
in {
	den.aspects.terminal.darwin = {pkgs, ...}: {
		fonts.packages = [
			pkgs.nerd-fonts.iosevka
		];
	};

	den.aspects.terminal.homeManager = {
		config,
		pkgs,
		lib,
		...
	}: {
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
				mosh
				ouch
				ov
				sd
				tree
			]
			++ lib.optionals stdenv.isLinux [
				ghostty.terminfo
			];

		home.sessionVariables = {
			FZF_DEFAULT_OPTS = ''
				--bind=alt-k:up,alt-j:down
				--expect=tab,enter
				--layout=reverse
				--delimiter='\t'
				--with-nth=1
				--preview-window='border-rounded' --prompt='  ' --marker=' ' --pointer=' '
				--separator='─' --scrollbar='┃' --layout='reverse'

				--color=bg+:${palette.overlay},bg:${palette.base},spinner:${palette.gold},hl:${palette.rose}
				--color=fg:${palette.subtle},header:${palette.pine},info:${palette.foam},pointer:${palette.iris}
				--color=marker:${palette.love},fg+:${palette.text},prompt:${palette.subtle},hl+:${palette.rose}
				--color=selected-bg:${palette.overlay}
				--color=border:${palette.highlightMed},label:${palette.text}
			'';
		};

		xdg.configFile."ghostty/config".text = ''
			command = ${pkgs.nushell}/bin/nu
			theme = ${theme.ghosttyName}
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

		xdg.configFile = {
			"glow/glow.yml".text =
				lib.concatStringsSep "\n" [
					"# style name or JSON path (default \"auto\")"
					"style: \"${config.xdg.configHome}/glow/${theme.slug}.json\""
					"# mouse support (TUI-mode only)"
					"mouse: false"
					"# use pager to display markdown"
					"pager: false"
					"# word-wrap at width"
					"width: 80"
					"# show all files, including hidden and ignored."
					"all: false"
					""
				];
			"glow/${theme.slug}.json".source = ./_terminal/rose-pine-dawn-glow.json;
		};

		programs.bat = {
			enable = true;
			config = {
				theme = theme.displayName;
				pager = "ov";
			};
			themes = {
				"${theme.displayName}" = {
					src =
						pkgs.fetchFromGitHub {
							owner = "rose-pine";
							repo = "tm-theme";
							rev = "23bb25b9c421cdc9ea89ff3ad3825840cd19d65d";
							hash = "sha256-GUFdv5V5OZ2PG+gfsbiohMT23LWsrZda34ReHBr2Xy0=";
						};
					file = "dist/${theme.slug}.tmTheme";
				};
			};
		};

		programs.fzf = {
			enable = true;
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
	};
}
