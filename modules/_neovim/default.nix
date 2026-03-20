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
		./plugins/hardtime.nix
		./plugins/harpoon.nix
		./plugins/hunk.nix
		./plugins/jj-diffconflicts.nix
		./plugins/jj-nvim.nix
		./plugins/lsp.nix
		./plugins/mini.nix
		./plugins/oil.nix
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
				extend_background_behind_borders = false;
				styles = {
					italic = false;
				};
			};
		};
	};

	home.shellAliases = {
		v = "nvim";
	};
}
