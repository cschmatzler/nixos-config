{pkgs, ...}: {
	programs.nixvim = {
		plugins.treesitter = {
			enable = true;
			nixGrammars = true;
			grammarPackages = with pkgs.vimPlugins.nvim-treesitter-parsers; [
				bash
				css
				elixir
				javascript
				lua
				markdown
				markdown_inline
				nix
				regex
				typescript
				vim
			];
			settings = {
				highlight.enable = true;
			};
		};
	};
}
