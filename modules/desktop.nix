{...}: let
	aerospaceSettings = import ./_desktop/aerospace.nix;
in {
	den.aspects.desktop.homeManager = {...}: {
		programs.aerospace = {
			enable = true;
			launchd.enable = true;
			settings = aerospaceSettings;
		};
	};
}
