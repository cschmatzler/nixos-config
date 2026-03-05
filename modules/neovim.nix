{inputs, ...}: {
	den.aspects.neovim.homeManager = {pkgs, ...}: {
		imports = [
			inputs.nixvim.homeModules.nixvim
			./_neovim/default.nix
		];
	};
}
