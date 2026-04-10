{...}: {
	programs.nixvim.plugins.which-key = {
		enable = true;
		settings = {
			delay.__raw = ''
				function(ctx)
					return ctx.plugin and 0 or 150
				end
			'';
			notify = false;
			plugins = {
				marks = true;
				registers = true;
				spelling = {
					enabled = true;
					suggestions = 20;
				};
				presets = {
					operators = true;
					motions = true;
					text_objects = true;
					windows = true;
					nav = true;
					z = true;
					g = true;
				};
			};
			win = {
				border = "single";
				padding = [1 2];
				title = true;
				title_pos = "center";
			};
			layout = {
				width.min = 24;
				spacing = 3;
			};
			spec = [
				{
					__unkeyed-1 = "<leader>e";
					group = "Explore";
					icon = " ";
				}
				{
					__unkeyed-1 = "<leader>f";
					group = "Find";
					icon = " ";
				}
				{
					__unkeyed-1 = "<leader>l";
					mode = ["n" "x"];
					group = "LSP";
					icon = " ";
				}
				{
					__unkeyed-1 = "<leader>r";
					mode = ["n" "v"];
					group = "Review";
					icon = " ";
				}
				{
					__unkeyed-1 = "<leader>s";
					mode = ["n" "x"];
					group = "Sidekick";
					icon = " ";
				}
				{
					__unkeyed-1 = "<leader>t";
					group = "Tab";
					icon = "󰓩 ";
				}
				{
					__unkeyed-1 = "<leader>v";
					group = "VCS";
					icon = " ";
				}
				{
					__unkeyed-1 = "<leader>w";
					group = "Window";
					icon = " ";
				}
			];
		};
	};
}
