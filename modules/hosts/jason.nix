{den, ...}: {
	den.hosts.aarch64-darwin.jason.users.cschmatzler.aspect = "jason-cschmatzler";

	den.aspects.jason-cschmatzler = {
		includes = [
			den.aspects.user-darwin-laptop
			den.aspects.user-personal
		];
	};

	den.aspects.jason.includes = [
		(den.lib.perHost {
				includes = [den.aspects.host-darwin-base];

				darwin = {...}: {
					networking.hostName = "jason";
					networking.computerName = "jason";

					sops.secrets.opencode-api-key = {
						sopsFile = ../../secrets/opencode-api-key;
						format = "binary";
						owner = "cschmatzler";
						path = "/run/secrets/opencode-api-key";
					};
				};
			})
	];
}
