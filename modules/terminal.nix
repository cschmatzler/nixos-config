{...}: {
	den.aspects.terminal.homeManager = {
		pkgs,
		lib,
		...
	}: {
		xdg.configFile."ghostty/config".text = ''
			command = ${pkgs.nushell}/bin/nu
			theme = Catppuccin Latte
			window-padding-x = 12
			window-padding-y = 3
			window-padding-balance = true
			font-family = TX-02
			font-size = 16.5
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
				theme = "Catppuccin Latte";
				pager = "ov";
			};
			themes = {
				"Catppuccin Latte" = {
					src =
						pkgs.fetchFromGitHub {
							owner = "catppuccin";
							repo = "bat";
							rev = "6810349b28055dce54076712fc05fc68da4b8ec0";
							sha256 = "lJapSgRVENTrbmpVyn+UQabC9fpV1G1e+CdlJ090uvg=";
						};
					file = "themes/Catppuccin Latte.tmTheme";
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

				--color=bg+:#CCD0DA,bg:#EFF1F5,spinner:#DC8A78,hl:#D20F39
				--color=fg:#4C4F69,header:#D20F39,info:#8839EF,pointer:#DC8A78
				--color=marker:#7287FD,fg+:#4C4F69,prompt:#8839EF,hl+:#D20F39
				--color=selected-bg:#BCC0CC
				--color=border:#9CA0B0,label:#4C4F69
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
