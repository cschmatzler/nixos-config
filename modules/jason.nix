{den, ...}: {
	den.aspects.jason.includes = [
		(den.lib.perHost {
				includes = [
					den.aspects.darwin-system
					den.aspects.core
					den.aspects.tailscale
				];

				darwin = {...}: {
					networking.hostName = "jason";
					networking.computerName = "jason";
				};
			})
		(den.lib.perUser {
				includes = [den.aspects.desktop];

				homeManager = {...}: {
					fonts.fontconfig.enable = true;
					programs.git.settings.user.email = "christoph@schmatzler.com";
				};
			})
	];
}
