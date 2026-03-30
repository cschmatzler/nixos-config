{...}: let
	local = import ./_lib/local.nix;
	palette = (import ./_lib/theme.nix).rosePineDawn.hex;
in {
	den.aspects.dev-tools.homeManager = {
		pkgs,
		lib,
		...
	}: let
		name = local.user.fullName;
	in {
		home.packages = with pkgs;
			[
				alejandra
				ast-grep
				bun
				delta
				deadnix
				devenv
				docker
				docker-compose
				lazydocker
				gh
				gnumake
				hyperfine
				jj-ryu
				jj-starship
				nil
				nodejs_24
				nurl
				pnpm
				postgresql_17
				serie
				sqlite
				statix
				tea
				tokei
				tree-sitter
				(pkgs.writeShellApplication {
						name = "tuist-pr";
						runtimeInputs = with pkgs; [coreutils fzf gh git nushell];
						text = ''
							exec nu ${./_dev-tools/tuist-pr.nu} "$@"
						'';
					})
			]
			++ lib.optionals stdenv.isDarwin [
				xcodes
			]
			++ lib.optionals stdenv.isLinux [
				gcc15
			];

		# Git configuration
		programs.git = {
			enable = true;
			ignores = ["*.swp"];
			settings = {
				user.name = name;
				init.defaultBranch = "main";
				core = {
					editor = "vim";
					autocrlf = "input";
					pager = "delta";
				};
				credential = {
					helper = "!gh auth git-credential";
					"https://github.com".useHttpPath = true;
					"https://gist.github.com".useHttpPath = true;
				};
				pull.rebase = true;
				rebase.autoStash = true;
				interactive.diffFilter = "delta --color-only";
				delta = {
					navigate = true;
					line-numbers = true;
					syntax-theme = "GitHub";
					side-by-side = true;
					pager = "less -FRX";
				};
				pager = {
					diff = "delta";
					log = "delta";
					show = "delta";
				};
			};
			lfs = {
				enable = true;
			};
		};

		# Jujutsu configuration
		programs.jujutsu = {
			enable = true;
			settings = {
				user = {
					name = name;
					email = local.user.emails.personal;
				};
				git = {
					sign-on-push = true;
					subprocess = true;
					write-change-id-header = true;
					private-commits = "description(glob:'wip:*') | description(glob:'WIP:*') | description(exact:'')";
				};
				fsmonitor = {
					backend = "watchman";
				};
				ui = {
					default-command = "status";
					diff-formatter = ":git";
					pager = ["delta" "--pager" "less -FRX"];
					diff-editor = ["nvim" "-c" "DiffEditor $left $right $output"];
					movement = {
						edit = true;
					};
				};
				aliases = {
					n = ["new"];
					tug = ["bookmark" "move" "--from" "closest_bookmark(@-)" "--to" "@-"];
					stack = ["log" "-r" "stack()"];
					retrunk = ["rebase" "-d" "trunk()"];
					bm = ["bookmark"];
					gf = ["git" "fetch"];
					gp = ["git" "push"];
				};
				revset-aliases = {
					"closest_bookmark(to)" = "heads(::to & bookmarks())";
					"closest_pushable(to)" = "heads(::to & mutable() & ~description(exact:\"\") & (~empty() | merges()))";
					"mine()" = "author(\"${local.user.emails.personal}\")";
					"wip()" = "mine() ~ immutable()";
					"open()" = "mine() ~ ::trunk()";
					"current()" = "@:: & mutable()";
					"stack()" = "reachable(@, mutable())";
				};
				templates = {
					draft_commit_description = ''
						concat(
						  coalesce(description, default_commit_description, "\n"),
						  surround(
						    "\nJJ: This commit contains the following changes:\n", "",
						    indent("JJ:     ", diff.stat(72)),
						  ),
						  "\nJJ: ignore-rest\n",
						  diff.git(),
						)
					'';
				};
			};
		};

		# JJUI configuration
		programs.jjui = {
			enable = true;
			settings.ui.colors = {
				text = {fg = palette.text;};
				dimmed = {fg = palette.muted;};
				selected = {
					bg = palette.overlay;
					fg = palette.text;
					bold = true;
				};
				border = {fg = palette.muted;};
				title = {
					fg = palette.iris;
					bold = true;
				};
				shortcut = {
					fg = palette.pine;
					bold = true;
				};
				matched = {
					fg = palette.gold;
					bold = true;
				};
				"revisions selected" = {
					bg = palette.overlay;
					fg = palette.text;
					bold = true;
				};
				"status" = {bg = palette.overlay;};
				"status title" = {
					bg = palette.iris;
					fg = palette.base;
					bold = true;
				};
				"status shortcut" = {fg = palette.pine;};
				"status dimmed" = {fg = palette.muted;};
				"menu" = {bg = palette.base;};
				"menu selected" = {
					bg = palette.overlay;
					fg = palette.text;
					bold = true;
				};
				"menu border" = {fg = palette.muted;};
				"menu title" = {
					fg = palette.iris;
					bold = true;
				};
				"menu shortcut" = {fg = palette.pine;};
				"menu matched" = {
					fg = palette.gold;
					bold = true;
				};
				"preview border" = {fg = palette.muted;};
				"help" = {bg = palette.base;};
				"help border" = {fg = palette.muted;};
				"help title" = {
					fg = palette.iris;
					bold = true;
				};
				"confirmation" = {bg = palette.base;};
				"confirmation border" = {fg = palette.muted;};
				"confirmation selected" = {
					bg = palette.overlay;
					fg = palette.text;
					bold = true;
				};
				"confirmation dimmed" = {fg = palette.muted;};
				source_marker = {
					fg = palette.foam;
					bold = true;
				};
				target_marker = {
					fg = palette.rose;
					bold = true;
				};
			};
		};

		# Direnv configuration
		programs.direnv = {
			enable = true;
			nix-direnv.enable = true;
		};

		# Mise configuration
		programs.mise = {
			enable = true;
			enableNushellIntegration = true;
			globalConfig.settings = {
				auto_install = false;
			};
		};
	};
}
