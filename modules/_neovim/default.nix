{
	imports = [
		./autocmd.nix
		./mappings.nix
		./options.nix
		./plugins/blink-cmp.nix
		./plugins/conform.nix
		./plugins/grug-far.nix
		./plugins/harpoon.nix
		./plugins/hunk.nix
		./plugins/jj-diffconflicts.nix
		./plugins/jj-nvim.nix
		./plugins/code-review.nix
		./plugins/diffview.nix
		./plugins/lsp.nix
		./plugins/mini.nix
		./plugins/oil.nix
		./plugins/opencode.nix
		./plugins/toggleterm.nix
		./plugins/treesitter.nix
		./plugins/zk.nix
	];

	programs.nixvim = {
		enable = true;
		defaultEditor = true;
		luaLoader.enable = true;
		colorschemes.rose-pine = {
			enable = true;
			settings = {
				variant = "dawn";
			};
		};
		extraConfigLua = ''
			vim.ui.select = MiniPick.ui_select
		'';
	};

	home.shellAliases = {
		v = "nvim";
	};
}
