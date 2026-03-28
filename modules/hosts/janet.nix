{den, ...}: {
	den.hosts.aarch64-darwin.janet.users.cschmatzler.aspect = "janet-cschmatzler";

	den.aspects.janet-cschmatzler = {
		includes = [
			den.aspects.user-darwin-laptop
			den.aspects.user-personal
		];
	};

	den.aspects.janet.includes = [
		(den.lib.perHost {
				includes = [den.aspects.host-darwin-base];

				darwin = {...}: {
					networking.hostName = "janet";
					networking.computerName = "janet";

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
