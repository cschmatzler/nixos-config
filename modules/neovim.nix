{inputs, ...}: {
	den.aspects.neovim.homeManager = {pkgs, ...}: {
		imports = [
			inputs.nixvim.homeModules.nixvim
			./_neovim/default.nix
		];

		_module.args.nvim-plugin-sources = {
			code-review-nvim = inputs.code-review-nvim;
			difftastic-nvim = inputs.difftastic-nvim;
			neojj = inputs.neojj;
		};

		programs.nixvim.nixpkgs.source = inputs.nixpkgs;
		programs.nixvim.version.enableNixpkgsReleaseCheck = false;
	};
}
