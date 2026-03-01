{
	programs.jujutsu = {
		enable = true;
		settings = {
			user = {
				name = "Christoph Schmatzler";
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
}
