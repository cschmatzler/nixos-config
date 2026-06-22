{
	pkgs,
	nvim-plugin-sources,
	...
}: let
	code-review-nvim =
		pkgs.vimUtils.buildVimPlugin {
			pname = "code-review-nvim";
			version = "unstable";
			src = nvim-plugin-sources.code-review-nvim;
			doCheck = false;
		};
in {
	programs.nixvim = {
		extraPlugins = [
			code-review-nvim
		];
		extraConfigLua = ''
			require('code-review').setup({
				keymaps = false,
				comment = {
					storage = {
						backend = "file",
					},
				},
				ui = {
					input_window = {
						title = "Review",
						height = 4,
						border = "single",
					},
					preview = {
						float = {
							border = "single",
						},
					},
				},
			})

			-- code-review.nvim's floating input can leave difftastic.nvim windows
			-- scrolled/cursored back at the first line after a comment is submitted.
			-- Preserve the originating window view around the async input callback.
			local code_review_ui = require("code-review.ui")
			local show_comment_input = code_review_ui.show_comment_input
			code_review_ui.show_comment_input = function(callback, context, title)
				local source_win = vim.api.nvim_get_current_win()
				local source_view = vim.fn.winsaveview()

				show_comment_input(function(text)
					callback(text)

					vim.schedule(function()
						if vim.api.nvim_win_is_valid(source_win) then
							pcall(vim.api.nvim_win_call, source_win, function()
								vim.fn.winrestview(source_view)
							end)
						end
					end)
				end, context, title)
			end
		'';
	};
}
