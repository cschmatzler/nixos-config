{
	den,
	lib,
	...
}: let
	hostLib = import ../_lib/hosts.nix {inherit den lib;};
	local = import ../_lib/local.nix;
	host = "janet";
	hostMeta = local.hosts.janet;
in
	hostLib.mkHostConfig {
		system = hostMeta.system;
		inherit host;
		user = local.user.name;
		userIncludes = [
			den.aspects.user-darwin-laptop
			den.aspects.user-personal
		];
		hostIncludes = [
			den.aspects.host-darwin-base
			den.aspects.opencode-api-key
		];
		darwin = {...}: {
			networking.hostName = host;
			networking.computerName = host;
		};
	}
