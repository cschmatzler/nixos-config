{
	pkgs,
	nvim-plugin-sources,
	...
}: {
	programs.nixvim.extraPlugins = [
		(pkgs.vimUtils.buildVimPlugin {
				pname = "jj-diffconflicts";
				version = "unstable";
				src = nvim-plugin-sources.jj-diffconflicts;
			})
	];
}
