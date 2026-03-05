{den, ...}: {
	den.aspects.cschmatzler.includes = [
		den.provides.primary-user
		den.aspects.shell
		den.aspects.ssh-client
	];

	den.aspects.cschmatzler.homeManager = {
		lib,
		pkgs,
		inputs',
		...
	}: {
		programs.home-manager.enable = true;

		home.packages = pkgs.callPackage ./_lib/packages.nix {inputs = inputs';};

		home.activation =
			lib.mkIf pkgs.stdenv.isDarwin {
				"setWallpaper" =
					lib.hm.dag.entryAfter ["revealHomeLibraryDirectory"] ''
						echo "[+] Setting wallpaper"
						${import ./_lib/wallpaper.nix {inherit pkgs;}}/bin/set-wallpaper-script
					'';
			};
	};
}
