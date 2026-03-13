{inputs, ...}: {
	den.aspects.neovim.homeManager = {pkgs, ...}: {
		imports = [
			inputs.nixvim.homeModules.nixvim
			./_neovim/default.nix
		];

		_module.args.nvim-plugin-sources = {
			opencode-nvim = inputs.opencode-nvim;
			code-review-nvim = inputs.code-review-nvim;
			jj-nvim = inputs.jj-nvim;
			jj-diffconflicts = inputs.jj-diffconflicts;
		};
	};
}
