{pkgs, ...}: let
	code-review-nvim =
		pkgs.vimUtils.buildVimPlugin {
			pname = "code-review-nvim";
			version = "unstable-2026-03-10";
			src =
				pkgs.fetchFromGitHub {
					owner = "choplin";
					repo = "code-review.nvim";
					rev = "ed91462e20bd08c3be71efb11a4a7d00459f0b47";
					hash = "sha256-WpbQswkUpB4Nblos8+5UE5I/PHUQOi+RQ+hj4CCdL4o=";
				};
			doCheck = false;
		};
in {
	programs.nixvim = {
		extraPlugins = [
			code-review-nvim
		];
		extraConfigLua = ''
			require('code-review').setup({
				keymaps = false,
			})
		'';
	};
}
