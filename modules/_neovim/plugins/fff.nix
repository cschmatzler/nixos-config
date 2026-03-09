{pkgs, ...}: {
	programs.nixvim = {
		extraPlugins = [pkgs.vimPlugins.fff-nvim];
		extraConfigLua = ''
			require('fff').setup({})
		'';
	};
}
