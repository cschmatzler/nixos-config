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
			postPatch = ''
				# Widen sign column and move border further left for more padding
				sed -i "s/signcolumn', 'yes'/signcolumn', 'yes:2'/" lua/opencode/ui/output_window.lua
				sed -i "s/, -3)/, -5)/g" lua/opencode/ui/formatter.lua
				sed -i "s/win_col = -3/win_col = -5/g" lua/opencode/ui/formatter.lua
				# Fix off-by-one: user border starts 1 line too early (bleeds into header empty line)
				sed -i 's/start_line = output:get_line_count() *$/start_line = output:get_line_count() + 1/' lua/opencode/ui/formatter.lua
				# Fix file mention border starting 1 line too early
				sed -i 's/file_line - 1, file_line/file_line, file_line/' lua/opencode/ui/formatter.lua
			'';
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
