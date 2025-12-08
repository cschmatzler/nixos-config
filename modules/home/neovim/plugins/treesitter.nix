{pkgs, ...}: {
	programs.nixvim.plugins.treesitter = {
		enable = true;
		settings = {
			highlight.enable = true;
			indent.enable = true;
		};
		grammarPackages = with pkgs.vimPlugins.nvim-treesitter.builtGrammars; [
			bash
			elixir
			fish
			heex
			json
			markdown
			nix
			toml
			tsx
			typescript
			yaml
		];
	};
}
