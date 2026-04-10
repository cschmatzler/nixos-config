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
						local p = require("rose-pine.palette")
						vim.api.nvim_set_hl(0, "NormalFloat", { bg = p.base })
						vim.api.nvim_set_hl(0, "FloatTitle", { fg = p.foam, bg = p.base, bold = true })
						vim.api.nvim_set_hl(0, "Pmenu", { fg = p.subtle, bg = p.base })
						vim.api.nvim_set_hl(0, "PmenuExtra", { fg = p.muted, bg = p.base })
						vim.api.nvim_set_hl(0, "PmenuKind", { fg = p.foam, bg = p.base })
						vim.api.nvim_set_hl(0, "PmenuSbar", { bg = p.base })
						vim.api.nvim_set_hl(0, "MiniPickPrompt", { bg = p.base, bold = true })
						vim.api.nvim_set_hl(0, "MiniPickBorderText", { bg = p.base })
						vim.api.nvim_set_hl(0, "OpencodeInputLegend", { fg = p.text, bg = p.highlight_med, bold = false })
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
