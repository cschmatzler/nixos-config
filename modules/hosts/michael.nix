{
	den,
	inputs,
	lib,
	...
}: let
	hostLib = import ../_lib/hosts.nix {inherit den lib;};
	local = import ../_lib/local.nix;
	host = "michael";
	hostMeta = local.hosts.michael;
in
	hostLib.mkHostConfig {
		system = hostMeta.system;
		inherit host;
		user = local.user.name;
		userIncludes = [den.aspects.user-minimal];
		hostIncludes = [
			den.aspects.host-public-server
			den.aspects.gitea
		];
		nixos = {modulesPath, ...}: {
			imports = [
				(modulesPath + "/installer/scan/not-detected.nix")
				./_parts/michael/disk-config.nix
				./_parts/michael/hardware-configuration.nix
				inputs.disko.nixosModules.default
			];
		};
	}
