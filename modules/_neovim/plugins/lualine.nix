{...}: {
	programs.nixvim.plugins.lualine = {
		enable = true;
		settings = {
			options = {
				theme = "rose-pine";
				globalstatus = true;
				component_separators = {
					left = "│";
					right = "│";
				};
				section_separators = {
					left = "";
					right = "";
				};
			};
			sections = {
				lualine_a = ["mode"];
				lualine_b = ["branch" "diff"];
				lualine_c = ["filename"];
				lualine_x = ["diagnostics"];
				lualine_y = ["filetype"];
				lualine_z = ["location"];
			};
			inactive_sections = {
				lualine_a = [];
				lualine_b = [];
				lualine_c = ["filename"];
				lualine_x = ["location"];
				lualine_y = [];
				lualine_z = [];
			};
		};
	};
}
