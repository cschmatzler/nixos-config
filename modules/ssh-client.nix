{...}: {
	den.aspects.ssh-client.homeManager = {
		config,
		pkgs,
		...
	}: let
		homeDir = "${
			if pkgs.stdenv.hostPlatform.isDarwin
			then "/Users"
			else "/home"
		}/${config.home.username}";
	in {
		programs.ssh = {
			enable = true;
			enableDefaultConfig = false;
			includes = [
				"${homeDir}/.ssh/config_external"
			];
			matchBlocks = {
				"*" = {};
				"github.com" = {
					identitiesOnly = true;
					identityFile = [
						"${homeDir}/.ssh/id_ed25519"
					];
				};
			};
		};
	};
}
