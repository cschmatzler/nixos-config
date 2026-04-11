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
	hostLib.mkHostConfig {
		system = hostMeta.system;
		inherit host;
		user = local.user.name;
		userIncludes = [den.aspects.user-darwin-laptop];
		userHomeManager = {...}: {
			programs.git.settings.user.email = local.user.emails.work;
		};
		hostIncludes = [
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
