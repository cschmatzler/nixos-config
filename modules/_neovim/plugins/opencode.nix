{pkgs, ...}: let
	opencode-nvim =
		pkgs.vimUtils.buildVimPlugin {
			pname = "opencode-nvim";
			version = "unstable-2026-03-07";
			src =
				pkgs.fetchFromGitHub {
					owner = "sudo-tee";
					repo = "opencode.nvim";
					rev = "dffa3f39a8251c7ba53b1544d8536b5f51b4e90d";
					hash = "sha256-KxIuToMpyo/Yi4xKirMV8Fznlma6EL1k4YQm5MQdGw4=";
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
		'';
	};
}
