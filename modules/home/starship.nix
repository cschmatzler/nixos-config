{
	programs.starship = {
		enable = true;
		enableFishIntegration = true;
		settings = {
			add_newline = true;
			command_timeout = 200;
			format = "$directory$git_branch$git_commit$git_status$git_state$git_metrics\n$character";
			character = {
				error_symbol = "[✗ ](bold #d20f39)";
				success_symbol = "[❯](bold #40a02b)[❯](bold #df8e1d)[❯](bold #179299)";
			};
			directory = {
				truncation_length = 2;
				truncation_symbol = "…/";
				repo_root_style = "bold cyan";
				repo_root_format = "[$repo_root]($repo_root_style)[$path]($style)[$read_only]($read_only_style) ";
			};
			git_branch = {
				format = " @[$branch(:$remote_branch)]($style)";
				symbol = "";
				style = "bold #40a02b";
				truncation_length = 28;
			};
			git_commit = {
				commit_hash_length = 4;
				only_detached = false;
				tag_disabled = true;
				format = " [$hash]($style)";
				style = "bold #1e66f5";
			};
			git_status = {
				format = " [$ahead_behind$staged$modified$renamed$deleted$typechanged$untracked$stashed$conflicted]($style)";
				style = "bold #df8e1d";
				ahead = " a+$count";
				behind = " b+$count";
				diverged = " div:$ahead_count/$behind_count";
				staged = " s:$count";
				modified = " m:$count";
				renamed = " r:$count";
				deleted = " d:$count";
				typechanged = " t:$count";
				untracked = " u:$count";
				stashed = " st:$count";
				conflicted = " x:$count";
			};
			git_state = {
				format = " {$state($progress_current/$progress_total)}($style)";
				style = "bold #d20f39";
			};
			git_metrics = {
				disabled = false;
				format = " [+$added]($added_style)/[-$deleted]($deleted_style)";
				added_style = "bold #40a02b";
				deleted_style = "bold #d20f39";
			};
		};
	};
}
