{...}: {
	den.aspects.dev-tools.homeManager = {
		pkgs,
		lib,
		...
	}: let
		name = "Christoph Schmatzler";
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
					email = "christoph@schmatzler.com";
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
					"mine()" = "author(\"christoph@schmatzler.com\")";
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
				text = {fg = "#575279";};
				dimmed = {fg = "#9893a5";};
				selected = {
					bg = "#f2e9e1";
					fg = "#575279";
					bold = true;
				};
				border = {fg = "#9893a5";};
				title = {
					fg = "#907aa9";
					bold = true;
				};
				shortcut = {
					fg = "#286983";
					bold = true;
				};
				matched = {
					fg = "#ea9d34";
					bold = true;
				};
				"revisions selected" = {
					bg = "#f2e9e1";
					fg = "#575279";
					bold = true;
				};
				"status" = {bg = "#f2e9e1";};
				"status title" = {
					bg = "#907aa9";
					fg = "#faf4ed";
					bold = true;
				};
				"status shortcut" = {fg = "#286983";};
				"status dimmed" = {fg = "#9893a5";};
				"menu" = {bg = "#faf4ed";};
				"menu selected" = {
					bg = "#f2e9e1";
					fg = "#575279";
					bold = true;
				};
				"menu border" = {fg = "#9893a5";};
				"menu title" = {
					fg = "#907aa9";
					bold = true;
				};
				"menu shortcut" = {fg = "#286983";};
				"menu matched" = {
					fg = "#ea9d34";
					bold = true;
				};
				"preview border" = {fg = "#9893a5";};
				"help" = {bg = "#faf4ed";};
				"help border" = {fg = "#9893a5";};
				"help title" = {
					fg = "#907aa9";
					bold = true;
				};
				"confirmation" = {bg = "#faf4ed";};
				"confirmation border" = {fg = "#9893a5";};
				"confirmation selected" = {
					bg = "#f2e9e1";
					fg = "#575279";
					bold = true;
				};
				"confirmation dimmed" = {fg = "#9893a5";};
				source_marker = {
					fg = "#56949f";
					bold = true;
				};
				target_marker = {
					fg = "#d7827e";
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
