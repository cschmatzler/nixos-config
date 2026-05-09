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
						vim.api.nvim_set_hl(0, "SnacksPickerBorder", { fg = p.highlight_high, bg = p.base })
						vim.api.nvim_set_hl(0, "SnacksPickerTitle", { fg = p.foam, bg = p.base, bold = true })
						vim.api.nvim_set_hl(0, "SnacksPickerPrompt", { fg = p.iris, bg = p.base, bold = true })
						vim.api.nvim_set_hl(0, "SnacksInputBorder", { fg = p.highlight_high, bg = p.base })
						vim.api.nvim_set_hl(0, "SnacksInputTitle", { fg = p.foam, bg = p.base, bold = true })
						vim.api.nvim_set_hl(0, "SnacksIndent", { fg = p.highlight_med })
						vim.api.nvim_set_hl(0, "SnacksIndentScope", { fg = p.iris })
						vim.api.nvim_set_hl(0, "WhichKeyNormal", { bg = p.base })
						vim.api.nvim_set_hl(0, "WhichKeyBorder", { fg = p.highlight_high, bg = p.base })
						vim.api.nvim_set_hl(0, "WhichKeyTitle", { fg = p.foam, bg = p.base, bold = true })
						vim.api.nvim_set_hl(0, "NoiceCmdlinePopupBorder", { fg = p.iris, bg = p.base })
						vim.api.nvim_set_hl(0, "NoiceCmdlineIcon", { fg = p.foam, bg = p.base })
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
