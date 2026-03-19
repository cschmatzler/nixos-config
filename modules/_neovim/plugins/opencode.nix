{
	pkgs,
	nvim-plugin-sources,
	...
}: let
	opencode-nvim =
		pkgs.vimUtils.buildVimPlugin {
			pname = "opencode-nvim";
			version = "unstable";
			src = nvim-plugin-sources.opencode-nvim;
			doCheck = false;
		};
in {
	programs.nixvim = {
		autoCmd = [
			{
				event = "FileType";
				group = "Christoph";
				pattern = "opencode,opencode_output";
				callback.__raw = ''
					function()
						vim.b.ministatusline_disable = true
					end
				'';
			}
		];

		extraPlugins = [
			opencode-nvim
		];
		extraConfigLua = ''
			require("opencode").setup({
				server = {
					url = "localhost",
					port = 18822;
				},
				debug = {
					show_ids = false,
				},
				ui = {
					input = {
						text = {
							wrap = true,
						},
					},
					icons = {
						preset = "nerdfonts",
						overrides = {
							header_user = "▌ 󱦀 ",
							header_assistant = "󱚟 ",
							run = "󱆃 ",
							task = "󰉹 ",
							read = "󰈔 ",
							edit = "󰲶 ",
							write = "󰲶 ",
							plan = "󰉹 ",
							search = "󰍉 ",
							web = "󰖟 ",
							list = "󰉹 ",
							tool = "󱁤 ",
							snapshot = "󰙅 ",
							file = "󰈔 ",
							folder = "󰉋 ",
							attached_file = "󰏢 ",
							agent = "󱜚 ",
							reasoning = "󰌵 ",
							question = "󰋗 ",
							completed = "󰄬 ",
							pending = "󰦗 ",
							running = "󰑮 ",
							bash = "󱆃 ",
							command = "󰘳 ",
						},
					},
				},
			})

			local p = require("rose-pine.palette")
			local hl = vim.api.nvim_set_hl
			hl(0, "OpencodeBorder", { fg = p.muted })
			hl(0, "OpencodeToolBorder", { fg = p.base })
			hl(0, "OpencodeDiffAdd", { bg = p.highlight_med })
			hl(0, "OpencodeDiffDelete", { bg = p.overlay })
			hl(0, "OpencodeAgentPlan", { bg = p.iris, fg = p.surface })
			hl(0, "OpencodeAgentBuild", { bg = p.foam, fg = p.surface })
			hl(0, "OpencodeAgentCustom", { bg = p.gold, fg = p.surface })
			hl(0, "OpencodeContestualAction", { bg = p.highlight_med })
			hl(0, "OpencodeInputLegend", { bg = p.overlay, fg = p.subtle })
		'';
	};
}
