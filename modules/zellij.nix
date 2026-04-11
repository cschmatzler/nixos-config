{...}: let
	theme = (import ./_lib/theme.nix).rosePineDawn;
in {
	den.aspects.zellij.homeManager = {pkgs, ...}: let
		zellijFiles = import ./_zellij/default.nix {inherit pkgs theme;};
	in {
		programs.zellij.enable = true;

		xdg.configFile."zellij/config.kdl".text = zellijFiles.configKdl;
		xdg.configFile."zellij/layouts/default.kdl".text = zellijFiles.layoutKdl;
	};
}
