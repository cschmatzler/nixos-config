{inputs, ...}: {
	den.aspects.neovim.homeManager = {pkgs, ...}: {
		imports = [
			inputs.nixvim.homeModules.nixvim
			./_neovim/default.nix
		];

		home.packages = with pkgs; [
			copilot-language-server
		];

		_module.args.nvim-plugin-sources = {
			code-review-nvim = inputs.code-review-nvim;
			jj-nvim = inputs.jj-nvim;
			jj-diffconflicts = inputs.jj-diffconflicts;
		};
	};
}
