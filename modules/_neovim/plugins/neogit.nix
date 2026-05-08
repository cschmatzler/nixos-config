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
				untracked.folded = false;
				unstaged.folded = false;
				staged.folded = false;
				stashes.folded = false;
				unpulled.folded = false;
				unmerged.folded = true;
				recent.folded = true;
			};
		};
	};
}
