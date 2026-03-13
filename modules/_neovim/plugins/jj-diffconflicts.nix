{
	pkgs,
	nvim-plugin-sources,
	...
}: {
	programs.nixvim.extraPlugins = [
		(pkgs.vimUtils.buildVimPlugin {
				name = "jj-diffconflicts";
				src = nvim-plugin-sources.jj-diffconflicts;
			})
	];
}
