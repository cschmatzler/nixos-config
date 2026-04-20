{
	config,
	pkgs,
	...
}: let
	helpers = config.lib.nixvim;
in {
	programs.nixvim.plugins.fff = {
		enable = true;
		package = pkgs.vimPlugins.fff-nvim;
		settings = {
			base_path = helpers.mkRaw "vim.fn.getcwd()";
			hl = {
				normal = "NormalFloat";
				border = "SnacksPickerBorder";
				title = "SnacksPickerTitle";
				prompt = "SnacksPickerPrompt";
			};
		};
	};
}
