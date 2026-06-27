{
	den,
	lib,
	...
}: let
	hostLib = import ../_lib/hosts.nix {inherit den lib;};
	local = import ../_lib/local.nix;
	host = "tahani";
	hostMeta = local.hosts.tahani;
in
	hostLib.mkHostConfig {
		system = hostMeta.system;
		inherit host;
		user = local.user.name;
		userIncludes = [
			den.aspects.user-workstation
			den.aspects.user-personal
		];
		hostIncludes = [
			den.aspects.host-nixos-base
			den.aspects.ai-api-key
			den.aspects.ynab-api-key
			den.aspects.syncthing
		];
		nixos = {pkgs, ...}: {
			networking.hostName = host;

			environment.systemPackages = [pkgs._1password-cli];
			programs.nix-ld.enable = true;

			imports = [
				./_parts/tahani/networking.nix
			];

			virtualisation.docker.enable = true;
			users.users.${local.user.name}.extraGroups = [
				"docker"
			];
			swapDevices = [
				{
					device = "/swapfile";
					size = 16 * 1024;
				}
			];
		};
	}
