{inputs', ...}: {
	imports = [
		./autocmd.nix
		./mappings.nix
		./options.nix
		./plugins/blink-cmp.nix
		./plugins/code-review.nix
		./plugins/conform.nix
		./plugins/diffview.nix
		./plugins/grug-far.nix
		./plugins/harpoon.nix
		./plugins/hunk.nix
		./plugins/jj-diffconflicts.nix
		./plugins/jj-nvim.nix
		./plugins/lsp.nix
		./plugins/mini.nix
		./plugins/oil.nix
		./plugins/opencode.nix
		./plugins/render-markdown.nix
		./plugins/toggleterm.nix
		./plugins/treesitter.nix
		./plugins/zk.nix
	];

	programs.nixvim = {
		enable = true;
		defaultEditor = true;
		package = inputs'.neovim-nightly-overlay.packages.default;
		luaLoader.enable = true;
		colorschemes.rose-pine = {
			enable = true;
			settings = {
				variant = "dawn";
			};
		};
	};

	home.shellAliases = {
		v = "nvim";
	};
}
