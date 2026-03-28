{
	den,
	lib,
	...
}: let
	hostLib = import ../_lib/hosts.nix {inherit den lib;};
	local = import ../_lib/local.nix;
	host = "chidi";
	hostMeta = local.hosts.chidi;
in
	hostLib.mkUserHost {
		system = hostMeta.system;
		inherit host;
		user = local.user.name;
		includes = [den.aspects.user-darwin-laptop];
		homeManager = {...}: {
			programs.git.settings.user.email = local.user.emails.work;
		};
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

			homebrew.casks = [
				"slack"
			];
		};
	}
