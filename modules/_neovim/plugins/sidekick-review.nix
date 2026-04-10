{
	xdg.configFile."nvim/lua/sidekick_review.lua".text = builtins.readFile ./_sidekick-review/sidekick_review.lua;

	programs.nixvim.extraConfigLua = ''
		require('sidekick_review').setup()
	'';
}
