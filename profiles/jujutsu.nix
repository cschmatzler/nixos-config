{pkgs, ...}: {
	home.packages = [pkgs.jj-ryu];

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
			};
			diff = {
				tool = "delta";
			};
			ui = {
				default-command = "status";
				diff-formatter = ":git";
				pager = ["delta" "--pager" "less -FRX"];
				diff-editor = ["nvim" "-c" "DiffEditor $left $right $output"];
			};
			aliases = {
				n = ["new"];
				tug = ["bookmark" "move" "--from" "closest_bookmark(@-)" "--to" "@-"];
				stack = ["log" "-r" "ancestors((trunk()..@)::bookmarks() | @, 2)"];
				retrunk = ["rebase" "-d" "trunk()"];
			};
			revset-aliases = {
				"closest_bookmark(to)" = "heads(::to & bookmarks())";
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
