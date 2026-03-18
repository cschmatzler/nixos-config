{
	den,
	lib,
	...
}: {
	den.aspects.cschmatzler.includes = [
		den.provides.primary-user
		den.aspects.shell
		den.aspects.ssh-client
		den.aspects.terminal
		den.aspects.email
		den.aspects.atuin
		den.aspects.dev-tools
		den.aspects.neovim
		den.aspects.ai-tools
		den.aspects.secrets
		den.aspects.zellij
		den.aspects.zk
		({host, ...}:
				lib.optionalAttrs (host.class == "darwin") {
					includes = [den.aspects.desktop];
				})
	];

	den.aspects.cschmatzler.homeManager = {
		lib,
		pkgs,
		...
	}: {
		programs.home-manager.enable = true;

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
