{
	programs.nixvim.plugins.neogit = {
		enable = true;
		settings = {
			kind = "replace";
			commit_popup.kind = "floating";
			preview_buffer.kind = "floating";
			popup.kind = "floating";
			disable_commit_confirmation = true;
			integrations.diffview = true;
			sections = {
				untracked = {
					folded = false;
					hidden = false;
				};
				unstaged = {
					folded = false;
					hidden = false;
				};
				staged = {
					folded = false;
					hidden = false;
				};
				stashes = {
					folded = false;
					hidden = false;
				};
				unpulled = {
					folded = false;
					hidden = false;
				};
				unmerged = {
					folded = true;
					hidden = false;
				};
				recent = {
					folded = true;
					hidden = false;
				};
			};
		};
	};
}
