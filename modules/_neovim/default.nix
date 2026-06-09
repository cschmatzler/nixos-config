{inputs', ...}: let
	theme = (import ../_lib/theme.nix).catppuccinLatte;
in {
	imports = [
		./autocmd.nix
		./mappings.nix
		./options.nix
		./plugins/blink-cmp.nix
		./plugins/code-review.nix
		./plugins/conform.nix
		./plugins/diffview.nix
		./plugins/flash.nix
		./plugins/grug-far.nix
		./plugins/hardtime.nix
		./plugins/harpoon.nix
		./plugins/hunk.nix
		./plugins/lsp.nix
		./plugins/lualine.nix
		./plugins/mini.nix
		./plugins/neogit.nix
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
		colorschemes.${theme.neovim.colorscheme} = {
			enable = true;
			settings = {
				flavour = theme.neovim.flavour;
				term_colors = true;
				no_italic = true;
			};
		};
	};

	home.shellAliases = {
		v = "nvim";
	};
}
