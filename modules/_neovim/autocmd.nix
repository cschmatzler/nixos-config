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
						local p = require("catppuccin.palettes").get_palette("${theme.neovim.flavour}")
						p.love = p.red
						p.gold = p.yellow
						p.rose = p.rosewater
						p.pine = p.maroon
						p.foam = p.teal
						p.iris = p.mauve
						p.subtle = p.subtext1
						p.muted = p.overlay1
						p.highlight_high = p.surface2
						p.highlight_med = p.surface1
						p.highlight_low = p.surface0
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
						vim.api.nvim_set_hl(0, "DiffviewDiffChange", { fg = p.text, bg = p.highlight_low })
						vim.api.nvim_set_hl(0, "DiffviewDiffText", { fg = p.text, bg = p.highlight_med, bold = true })
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
				event = "User";
				group = "Christoph";
				pattern = "SnacksDashboardOpened";
				callback.__raw = ''
					function()
						vim.b.minitrailspace_disable = true
						pcall(function()
							require("mini.trailspace").unhighlight()
						end)
					end
				'';
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
