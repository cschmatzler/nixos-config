{pkgs, ...}: let
	jj-nvim =
		pkgs.vimUtils.buildVimPlugin {
			pname = "jj-nvim";
			version = "unstable-2026-03-10";
			src =
				pkgs.fetchFromGitHub {
					owner = "NicolasGB";
					repo = "jj.nvim";
					rev = "bbba4051c862473637e98277f284d12b050588ca";
					hash = "sha256-nokftWcAmmHX6UcH6O79xkLwbUpq1W8N9lf1e+NyGqE=";
				};
			doCheck = false;
		};
in {
	programs.nixvim = {
		extraPlugins = [
			jj-nvim
		];
		extraConfigLua = ''
			require('jj').setup({
				diff = {
					backend = "diffview",
				},
				cmd = {
					describe = {
						editor = { type = "buffer" },
					},
					log = {
						close_on_edit = false,
					},
				},
				-- Disable default keymaps — we set our own in mappings.nix
				ui = {
					log = {
						keymaps = true,
					},
				},
			})
		'';
	};
}
