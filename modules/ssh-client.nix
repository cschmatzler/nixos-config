{...}: {
	den.aspects.ssh-client.homeManager = {config, ...}: {
		programs.ssh = {
			enable = true;
			enableDefaultConfig = false;
			includes = [
				"${config.home.homeDirectory}/.ssh/config_external"
			];
			matchBlocks = {
				"*" = {};
				"github.com" = {
					identitiesOnly = true;
					identityFile = [
						"${config.home.homeDirectory}/.ssh/id_ed25519"
					];
				};
			};
		};
	};
}
