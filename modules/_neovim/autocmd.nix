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
						vim.api.nvim_set_hl(0, "OpencodeNormal", { bg = p.base })
						vim.api.nvim_set_hl(0, "OpencodeBackground", { bg = p.base })
						vim.api.nvim_set_hl(0, "OpencodeBorder", { fg = p.highlight_high, bg = p.base })
						vim.api.nvim_set_hl(0, "OpencodeToolBorder", { fg = p.highlight_med, bg = p.base })
						vim.api.nvim_set_hl(0, "OpencodeSessionDescription", { fg = p.text, bg = p.base })
						vim.api.nvim_set_hl(0, "OpencodeMention", { fg = p.iris, bg = p.base, bold = true })
						vim.api.nvim_set_hl(0, "OpencodeMessageRoleAssistant", { fg = p.foam, bold = true })
						vim.api.nvim_set_hl(0, "OpencodeMessageRoleUser", { fg = p.iris, bold = true })
						vim.api.nvim_set_hl(0, "OpencodeAgentPlan", { fg = p.base, bg = p.iris, bold = true })
						vim.api.nvim_set_hl(0, "OpencodeAgentBuild", { fg = p.base, bg = p.foam, bold = true })
						vim.api.nvim_set_hl(0, "OpencodeAgentCustom", { fg = p.base, bg = p.pine, bold = true })
						vim.api.nvim_set_hl(0, "OpencodeContextualActions", { fg = p.base, bg = p.gold, bold = true })
						vim.api.nvim_set_hl(0, "OpencodeInputLegend", { fg = p.text, bg = p.highlight_med, bold = false })
						vim.api.nvim_set_hl(0, "OpencodeHint", { fg = p.muted, bg = p.base })
						vim.api.nvim_set_hl(0, "OpencodeVariant", { fg = p.iris, bg = p.base, bold = true })
						vim.api.nvim_set_hl(0, "OpencodeContextBar", { fg = p.subtle, bg = p.base })
						vim.api.nvim_set_hl(0, "OpencodeContextFile", { fg = p.foam, bg = p.base })
						vim.api.nvim_set_hl(0, "OpencodeContextCurrentFile", { fg = p.pine, bg = p.base, bold = true })
						vim.api.nvim_set_hl(0, "OpencodeContextCurrentFileNotUpdated", { fg = p.muted, bg = p.base })
						vim.api.nvim_set_hl(0, "OpencodeContextAgent", { fg = p.iris, bg = p.base })
						vim.api.nvim_set_hl(0, "OpencodeContextSelection", { fg = p.gold, bg = p.base })
						vim.api.nvim_set_hl(0, "OpencodeContextError", { fg = p.love, bg = p.base })
						vim.api.nvim_set_hl(0, "OpencodeContextWarning", { fg = p.gold, bg = p.base })
						vim.api.nvim_set_hl(0, "OpencodeContextInfo", { fg = p.foam, bg = p.base })
						vim.api.nvim_set_hl(0, "OpencodeContextSwitchOn", { fg = p.pine, bg = p.base, bold = true })
						vim.api.nvim_set_hl(0, "OpencodePickerTime", { fg = p.muted, bg = p.base })
						vim.api.nvim_set_hl(0, "OpencodeDebugText", { fg = p.muted, bg = p.base })
						vim.api.nvim_set_hl(0, "OpencodeReference", { fg = p.foam, bg = p.base, underline = true })
						vim.api.nvim_set_hl(0, "OpencodeReasoningText", { fg = p.muted, bg = p.base })
						vim.api.nvim_set_hl(0, "OpencodePermissionTitle", { fg = p.gold, bg = p.base, bold = true })
						vim.api.nvim_set_hl(0, "OpencodeDialogOptionHover", { fg = p.base, bg = p.foam, bold = true })
						vim.api.nvim_set_hl(0, "OpencodeQuestionOption", { fg = p.text, bg = p.base })
						vim.api.nvim_set_hl(0, "OpencodeQuestionBorder", { fg = p.highlight_high, bg = p.base })
						vim.api.nvim_set_hl(0, "OpencodeQuestionTitle", { fg = p.foam, bg = p.base, bold = true })
						vim.api.nvim_set_hl(0, "OpencodeChangedLines", { bg = p.highlight_low })
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
