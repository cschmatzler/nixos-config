{
	programs.nixvim = {
		autoGroups = {
			Christoph = {};
		};

		autoCmd = [
			{
				event = ["VimEnter" "ColorScheme"];
				group = "Christoph";
				pattern = "*";
				callback.__raw = ''
					function()
						local base = require("rose-pine.palette").base
						local foam = require("rose-pine.palette").foam
						vim.api.nvim_set_hl(0, "NormalFloat", { bg = base })
						vim.api.nvim_set_hl(0, "FloatTitle", { fg = foam, bg = base, bold = true })
						vim.api.nvim_set_hl(0, "MiniPickPrompt", { bg = base, bold = true })
						vim.api.nvim_set_hl(0, "MiniPickBorderText", { bg = base })
					end
				'';
			}
			{
				event = "BufWritePre";
				group = "Christoph";
				pattern = "*";
				command = "%s/\\s\\+$//e";
			}
			{
				event = "BufReadPost";
				group = "Christoph";
				pattern = "*";
				command = "normal zR";
			}
			{
				event = "FileReadPost";
				group = "Christoph";
				pattern = "*";
				command = "normal zR";
			}
			{
				event = "FileType";
				group = "Christoph";
				pattern = "elixir,eelixir,heex";
				command = "setlocal expandtab tabstop=2 shiftwidth=2 softtabstop=2";
			}
		];
	};
}
