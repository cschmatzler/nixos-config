{
	pkgs,
	lib,
	constants,
	inputs,
	...
}: let
	setWallpaperScript = import ./wallpaper.nix {inherit pkgs;};
in {
	programs.home-manager.enable = true;

	home = {
		packages = pkgs.callPackage ./packages.nix {inherit inputs;};
		stateVersion = constants.stateVersions.homeManager;
		activation =
			lib.mkIf pkgs.stdenv.isDarwin {
				"setWallpaper" =
					lib.hm.dag.entryAfter ["revealHomeLibraryDirectory"] ''
						echo "[+] Setting wallpaper"
						${setWallpaperScript}/bin/set-wallpaper-script
					'';
			};
	};
}
