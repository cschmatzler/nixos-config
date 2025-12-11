{
	pkgs,
	lib,
	...
}: let
	setWallpaperScript = import ./darwin-wallpaper.nix {inherit pkgs;};
in {
	imports = [
		./darwin-ghostty.nix
	];

	home = {
		packages = pkgs.callPackage ./darwin-packages.nix {};
		activation = {
			"setWallpaper" =
				lib.hm.dag.entryAfter ["revealHomeLibraryDirectory"] ''
					echo "[+] Setting wallpaper"
					${setWallpaperScript}/bin/set-wallpaper-script
				'';
		};
	};
}
