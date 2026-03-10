{pkgs, ...}: {
	programs.nixvim = {
		extraPlugins = with pkgs.vimPlugins; [
			diffview-nvim
		];
		extraConfigLua = ''
			require('diffview').setup({
				enhanced_diff_hl = true,
				view = {
					default = { layout = "diff2_horizontal" },
					merge_tool = { layout = "diff3_mixed", disable_diagnostics = true },
					file_history = { layout = "diff2_horizontal" },
				},
				default_args = {
					DiffviewOpen = { "--imply-local" },
				},
				hooks = {
					diff_buf_read = function(bufnr)
						vim.opt_local.wrap = false
						vim.opt_local.list = false
					end,
				},
			})
		'';
	};
}
