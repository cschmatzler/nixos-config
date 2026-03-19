{den, ...}: {
	den.aspects.chidi.includes = [
		(den.lib.perHost {
				includes = [
					den.aspects.darwin-system
					den.aspects.core
					den.aspects.tailscale
				];

				darwin = {pkgs, ...}: {
					networking.hostName = "chidi";
					networking.computerName = "chidi";

					environment.systemPackages = with pkgs; [
						slack
					];
				};
			})
		(den.lib.perUser {
				includes = [den.aspects.desktop];

				homeManager = {...}: {
					fonts.fontconfig.enable = true;
					programs.git.settings.user.email = "christoph@tuist.dev";
				};
			})
	];
}
