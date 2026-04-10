{
	programs.nixvim.plugins.blink-cmp = {
		enable = true;
		settings = {
			keymap = {
				preset = "default";
				"<Tab>" = [
					"snippet_forward"
					{
						__raw = "function() return require('sidekick').nes_jump_or_apply() end";
					}
					"fallback"
				];
			};
			signature.enabled = true;
			completion = {
				accept = {
					auto_brackets = {
						enabled = true;
						semantic_token_resolution.enabled = false;
					};
				};
				documentation.auto_show = true;
			};
		};
	};
}
