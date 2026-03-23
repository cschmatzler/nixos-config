{
	den,
	inputs,
	...
}: {
	den.hosts.x86_64-linux.michael.users.cschmatzler.aspect = "michael-cschmatzler";

	den.aspects.michael-cschmatzler = {
		includes = [den.aspects.user-minimal];
	};

	den.aspects.michael.includes = [
		(den.lib.perHost {
				includes = [den.aspects.host-public-server];

				nixos = {modulesPath, ...}: {
					imports = [
						(modulesPath + "/installer/scan/not-detected.nix")
						./_parts/michael/backups.nix
						./_parts/michael/disk-config.nix
						./_parts/michael/gitea.nix
						./_parts/michael/hardware-configuration.nix
						inputs.disko.nixosModules.default
					];

					networking.hostName = "michael";
				};
			})
	];
}
