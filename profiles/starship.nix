{
	programs.starship = {
		enable = true;
		enableFishIntegration = true;
		settings = {
			add_newline = true;
			command_timeout = 2000;
			format = "$directory$git_branch$git_status$character";
			character = {
				error_symbol = "[✗ ](bold #e64553)";
				success_symbol = "[❯](bold #40a02b)[❯](bold #df8e1d)[❯](bold #dc8a78)";
			};
			directory = {
				truncation_length = 2;
				truncation_symbol = "…/";
				repo_root_style = "bold cyan";
				repo_root_format = "[$repo_root]($repo_root_style)[$path]($style)[$read_only]($read_only_style) ";
			};
			git_branch = {
				format = "[$symbol$branch(:$remote_branch)]($style) ";
				symbol = " ";
				style = "bold #8839ef";
				truncation_length = 20;
				truncation_symbol = "…";
			};
		git_status = {
			format = "([$all_status$ahead_behind]($style) )";
			style = "bold #df8e1d";
			conflicted = "conflict:$count ";
			ahead = "ahead:$count ";
			behind = "behind:$count ";
			diverged = "ahead:$ahead_count behind:$behind_count ";
			untracked = "new:$count ";
			stashed = "stash:$count ";
			modified = "mod:$count ";
			staged = "staged:$count ";
			renamed = "mv:$count ";
			deleted = "del:$count ";
		};
		};
	};
}
