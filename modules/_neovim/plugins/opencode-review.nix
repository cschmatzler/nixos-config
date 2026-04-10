{
	xdg.configFile."nvim/lua/opencode_review.lua".text = builtins.readFile ./_opencode-review/opencode_review.lua;

	programs.nixvim.extraConfigLua = ''
		require('opencode_review').setup()
	'';
}
