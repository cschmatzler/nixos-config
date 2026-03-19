{
	den,
	inputs,
	...
}: {
	den.aspects.michael.includes = [
		(den.lib.perHost {
				includes = [
					den.aspects.nixos-system
					den.aspects.core
					den.aspects.openssh
					den.aspects.fail2ban
					den.aspects.tailscale
				];

				nixos = {modulesPath, ...}: {
					imports = [
						(modulesPath + "/installer/scan/not-detected.nix")
						./_hosts/michael/backups.nix
						./_hosts/michael/disk-config.nix
						./_hosts/michael/gitea.nix
						./_hosts/michael/hardware-configuration.nix
						inputs.disko.nixosModules.default
					];

					networking.hostName = "michael";
				};
			})
	];
}
