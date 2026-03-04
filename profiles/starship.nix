{
	programs.starship = {
		enable = true;
		enableNushellIntegration = true;
		settings = {
			format = "$directory\${custom.scm}$all";
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
				shell = ["jj-starship" "--strip-bookmark-prefix" "cschmatzler/" "--truncate-name" "20" "--bookmarks-display-limit" "1"];
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
}
