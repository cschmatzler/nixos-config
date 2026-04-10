{pkgs, ...}: {
	programs.nixvim = {
		extraPlugins = with pkgs.vimPlugins; [
			sidekick-nvim
		];
		opts.autoread = true;
		extraConfigLua = ''
			require('sidekick').setup({
				cli = {
					picker = 'snacks',
					win = {
						keys = {
							hide_ctrl_q = false,
							stopinsert = { '<C-]>', 'stopinsert', mode = 't', desc = 'enter normal mode' },
						},
					},
				},
			})
		'';
	};
}
