{pkgs, ...}: {
	programs.nixvim = {
		extraPlugins = with pkgs.vimPlugins; [
			sidekick-nvim
		];
		opts.autoread = true;
		extraConfigLua = ''
			require('sidekick').setup({
				cli = {
					mux = {
						backend = 'zellij',
						enabled = true,
					},
					picker = 'snacks',
				},
			})
		'';
	};
}
