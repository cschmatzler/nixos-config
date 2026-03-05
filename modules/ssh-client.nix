{...}: {
	den.aspects.ssh-client.homeManager = {
		config,
		lib,
		pkgs,
		...
	}: {
		programs.ssh = {
			enable = true;
			enableDefaultConfig = false;
			includes = [
				(lib.mkIf pkgs.stdenv.hostPlatform.isLinux "/home/${config.home.username}/.ssh/config_external")
				(lib.mkIf pkgs.stdenv.hostPlatform.isDarwin "/Users/${config.home.username}/.ssh/config_external")
			];
			matchBlocks = {
				"*" = {};
				"github.com" = {
					identitiesOnly = true;
					identityFile = [
						(lib.mkIf pkgs.stdenv.hostPlatform.isLinux "/home/${config.home.username}/.ssh/id_ed25519")
						(lib.mkIf pkgs.stdenv.hostPlatform.isDarwin "/Users/${config.home.username}/.ssh/id_ed25519")
					];
				};
			};
		};
	};
}
