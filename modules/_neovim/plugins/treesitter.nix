{pkgs, ...}: {
	programs.nixvim = {
		plugins.treesitter = {
			enable = true;
			nixGrammars = true;
			grammarPackages = with pkgs.vimPlugins.nvim-treesitter-parsers; [
				css
				elixir
				javascript
				lua
				markdown
				markdown_inline
				nix
				typescript
			];
			settings = {
				highlight.enable = true;
				indent.enable = true;
			};
		};
	};
}
