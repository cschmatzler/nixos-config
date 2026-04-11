{
	pkgs,
	nvim-plugin-sources,
	...
}: let
	code-review-nvim =
		pkgs.vimUtils.buildVimPlugin {
			pname = "code-review-nvim";
			version = "unstable";
			src = nvim-plugin-sources.code-review-nvim;
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
				comment = {
					storage = {
						backend = "memory",
					},
				},
				ui = {
					input_window = {
						border = "single",
					},
					preview = {
						float = {
							border = "single",
						},
					},
				},
			})
		'';
	};
}
