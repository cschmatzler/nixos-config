let
	theme = (import ../_lib/theme.nix).catppuccinLatte;
in {
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
						local p = require("catppuccin.palettes").get_palette("${theme.neovimFlavor}")
						vim.api.nvim_set_hl(0, "NormalFloat", { bg = p.base })
						vim.api.nvim_set_hl(0, "FloatTitle", { fg = p.teal, bg = p.base, bold = true })
						vim.api.nvim_set_hl(0, "Pmenu", { fg = p.subtext1, bg = p.base })
						vim.api.nvim_set_hl(0, "PmenuExtra", { fg = p.overlay1, bg = p.base })
						vim.api.nvim_set_hl(0, "PmenuKind", { fg = p.teal, bg = p.base })
						vim.api.nvim_set_hl(0, "PmenuSbar", { bg = p.base })
						vim.api.nvim_set_hl(0, "SnacksPickerBorder", { fg = p.surface2, bg = p.base })
						vim.api.nvim_set_hl(0, "SnacksPickerTitle", { fg = p.teal, bg = p.base, bold = true })
						vim.api.nvim_set_hl(0, "SnacksPickerPrompt", { fg = p.mauve, bg = p.base, bold = true })
						vim.api.nvim_set_hl(0, "SnacksInputBorder", { fg = p.surface2, bg = p.base })
						vim.api.nvim_set_hl(0, "SnacksInputTitle", { fg = p.teal, bg = p.base, bold = true })
						vim.api.nvim_set_hl(0, "SnacksIndent", { fg = p.surface1 })
						vim.api.nvim_set_hl(0, "SnacksIndentScope", { fg = p.mauve })
						vim.api.nvim_set_hl(0, "WhichKeyNormal", { bg = p.base })
						vim.api.nvim_set_hl(0, "WhichKeyBorder", { fg = p.surface2, bg = p.base })
						vim.api.nvim_set_hl(0, "WhichKeyTitle", { fg = p.teal, bg = p.base, bold = true })
						vim.api.nvim_set_hl(0, "NoiceCmdlinePopupBorder", { fg = p.mauve, bg = p.base })
						vim.api.nvim_set_hl(0, "NoiceCmdlineIcon", { fg = p.teal, bg = p.base })
						vim.api.nvim_set_hl(0, "DiffviewDiffChange", { fg = p.text, bg = p.surface0 })
						vim.api.nvim_set_hl(0, "DiffviewDiffText", { fg = p.text, bg = p.surface1, bold = true })
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
