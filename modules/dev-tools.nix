{...}: let
	local = import ./_lib/local.nix;
	theme = (import ./_lib/theme.nix).catppuccinLatte;
in {
	den.aspects.dev-tools.homeManager = {
		pkgs,
		lib,
		...
	}: let
		userName = local.user.fullName;
		userEmail = local.user.emails.personal;
	in {
		home.packages = with pkgs;
			[
				alejandra
				ast-grep
				bun
				delta
				deadnix
				devenv
				fallow
				docker
				docker-compose
				lazydocker
				gh
				gnumake
				hyperfine
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
				user.name = userName;
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
				alias = {
					st = "status --short --branch";
					sw = "switch";
					co = "checkout";
					br = "branch";
					ci = "commit";
					cm = "commit -m";
					ca = "commit --amend";
					aa = "add --all";
					unstage = "restore --staged";
					last = "log -1 HEAD --stat";
					lg = "log --graph --decorate --oneline --abbrev-commit";
					graph = "log --graph --decorate --oneline --abbrev-commit --all";
					rb = "rebase";
					rbc = "rebase --continue";
					rba = "rebase --abort";
					pf = "push --force-with-lease";
					please = "push --force-with-lease";
					gone = "branch --merged";
				};
				fetch = {
					prune = true;
					pruneTags = true;
				};
				push = {
					autoSetupRemote = true;
					default = "current";
				};
				pull.rebase = true;
				rebase.autoStash = true;
				interactive.diffFilter = "delta --color-only";
				delta = {
					navigate = true;
					line-numbers = true;
					syntax-theme = theme.deltaSyntaxTheme;
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

		programs.jujutsu = {
			enable = true;
			settings = {
				user = {
					name = userName;
					email = userEmail;
				};
				git = {
					sign-on-push = true;
					subprocess = true;
					write-change-id-header = true;
					private-commits = "description(glob:'wip:*') | description(glob:'WIP:*') | description(exact:'')";
				};
				fsmonitor.backend = "watchman";
				ui = {
					default-command = "status";
					diff-formatter = ":git";
					pager = ["delta" "--pager" "less -FRX"];
					diff-editor = ["nvim" "-c" "DiffEditor $left $right $output"];
					movement.edit = true;
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
					"mine()" = "author(\"${userEmail}\")";
					"wip()" = "mine() ~ immutable()";
					"open()" = "mine() ~ ::trunk()";
					"current()" = "@:: & mutable()";
					"stack()" = "reachable(@, mutable())";
				};
				templates.draft_commit_description = ''
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

		programs.jjui.enable = true;
	};
}
