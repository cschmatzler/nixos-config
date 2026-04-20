{inputs', ...}: {
	imports = [
		./autocmd.nix
		./mappings.nix
		./options.nix
		./plugins/blink-cmp.nix
		./plugins/code-review.nix
		./plugins/conform.nix
		./plugins/diffview.nix
		./plugins/fff.nix
		./plugins/flash.nix
		./plugins/grug-far.nix
		./plugins/hardtime.nix
		./plugins/harpoon.nix
		./plugins/hunk.nix
		./plugins/jj-diffconflicts.nix
		./plugins/jj-nvim.nix
		./plugins/lsp.nix
		./plugins/lualine.nix
		./plugins/mini.nix
		./plugins/noice.nix
		./plugins/oil.nix
		./plugins/render-markdown.nix
		./plugins/snacks.nix
		./plugins/toggleterm.nix
		./plugins/treesitter.nix
		./plugins/which-key.nix
		./plugins/zk.nix
	];

	programs.nixvim = {
		enable = true;
		defaultEditor = true;
		package =
			inputs'.neovim-nightly-overlay.packages.default.overrideAttrs (old: {
					postInstall =
						(old.postInstall or "")
						+ ''
							if [ -e "$out/share/applications/org.neovim.nvim.desktop" ] && [ ! -e "$out/share/applications/nvim.desktop" ]; then
								ln -s org.neovim.nvim.desktop $out/share/applications/nvim.desktop
							fi
						'';
				});
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
