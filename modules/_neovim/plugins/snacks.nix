{...}: {
	programs.nixvim.plugins.snacks = {
		enable = true;
		settings = {
			bigfile.enabled = true;
			indent.enabled = true;
			dashboard = {
				enabled = true;
				sections = [
					{
						section = "header";
					}
					{
						section = "keys";
						gap = 1;
					}
					{
						icon = " ";
						title = "Recent Files";
						section = "recent_files";
						indent = 2;
						padding = [2 2];
					}
					{
						icon = " ";
						title = "Projects";
						section = "projects";
						indent = 2;
						padding = 2;
					}
				];
			};
			explorer = {
				enabled = true;
				replace_netrw = true;
			};
			input.enabled = true;
			notifier.enabled = true;
			picker = {
				enabled = true;
				ui_select = true;
				layout.layout.backdrop = false;
			};
			quickfile.enabled = true;
			scope.enabled = true;
			statuscolumn.enabled = true;
			words = {
				enabled = true;
				debounce = 150;
				notify_jump = false;
				notify_end = false;
			};
		};
	};
}
