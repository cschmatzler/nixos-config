{pkgs, ...}: let
	opencode-nvim =
		pkgs.vimUtils.buildVimPlugin {
			pname = "opencode-nvim";
			version = "unstable-2026-03-12";
			src =
				pkgs.fetchFromGitHub {
					owner = "sudo-tee";
					repo = "opencode.nvim";
					rev = "800c4f891f5d940f2805780a39872a0207b5a446";
					hash = "sha256-3xyZux5S8ThBsi7AC4AWnd2h2LEI5L+I5Am2PNWKu64=";
				};
			doCheck = false;
		};
in {
	programs.nixvim = {
		extraPlugins = [
			opencode-nvim
		];
		extraConfigLua = ''
			require("opencode").setup({
				debug = {
					show_ids = false,
				},
			})

			local hl = vim.api.nvim_set_hl
			hl(0, "OpencodeBorder", { fg = "#9893a5" })
			hl(0, "OpencodeToolBorder", { fg = "#cecacd" })
			hl(0, "OpencodeDiffAdd", { bg = "#dfeadf" })
			hl(0, "OpencodeDiffDelete", { bg = "#f2dde2" })
			hl(0, "OpencodeAgentPlan", { bg = "#907aa9", fg = "#fffaf3" })
			hl(0, "OpencodeAgentBuild", { bg = "#56949f", fg = "#fffaf3" })
			hl(0, "OpencodeAgentCustom", { bg = "#ea9d34", fg = "#fffaf3" })
			hl(0, "OpencodeContestualAction", { bg = "#dfdad9" })
			hl(0, "OpencodeInputLegend", { bg = "#f2e9e1", fg = "#797593" })
		'';
	};
}
