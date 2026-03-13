{
	pkgs,
	nvim-plugin-sources,
	...
}: let
	jj-nvim =
		pkgs.vimUtils.buildVimPlugin {
			pname = "jj-nvim";
			version = "unstable";
			src = nvim-plugin-sources.jj-nvim;
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
				ui = {
					log = {
						keymaps = true,
					},
				},
			})
		'';
	};
}
