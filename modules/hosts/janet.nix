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
	hostLib.mkUserHost {
		system = hostMeta.system;
		inherit host;
		user = local.user.name;
		includes = [
			den.aspects.user-darwin-laptop
			den.aspects.user-personal
		];
	}
	// hostLib.mkPerHostAspect {
		inherit host;
		includes = [
			den.aspects.host-darwin-base
			den.aspects.opencode-api-key
		];
		darwin = {...}: {
			networking.hostName = host;
			networking.computerName = host;
		};
	}
