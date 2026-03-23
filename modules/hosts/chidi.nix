{den, ...}: {
	den.hosts.aarch64-darwin.chidi.users.cschmatzler.aspect = "chidi-cschmatzler";

	den.aspects.chidi-cschmatzler = {
		includes = [den.aspects.user-darwin-laptop];

		homeManager = {...}: {
			programs.git.settings.user.email = "christoph@tuist.dev";
		};
	};

	den.aspects.chidi.includes = [
		(den.lib.perHost {
				includes = [den.aspects.host-darwin-base];

				darwin = {...}: {
					networking.hostName = "chidi";
					networking.computerName = "chidi";

					sops.secrets.opencode-api-key = {
						sopsFile = ../../secrets/opencode-api-key;
						format = "binary";
						owner = "cschmatzler";
						path = "/run/secrets/opencode-api-key";
					};

					homebrew.casks = [
						"slack"
					];
				};
			})
	];
}
