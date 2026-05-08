{
	programs.nixvim.plugins = {
		web-devicons.enable = true;

		diffview = {
			enable = true;
			settings = {
				enhanced_diff_hl = true;
				view = {
					default = {layout = "diff2_horizontal";};
					merge_tool = {
						layout = "diff3_mixed";
						disable_diagnostics = true;
					};
					file_history = {layout = "diff2_horizontal";};
				};
				default_args.DiffviewOpen = ["--imply-local"];
				hooks.diff_buf_read.__raw = ''
					function(bufnr)
						vim.opt_local.wrap = false
						vim.opt_local.list = false
					end
				'';
			};
		};
	};
}
