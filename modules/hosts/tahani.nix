{
	den,
	lib,
	...
}: let
	hostLib = import ../_lib/hosts.nix {inherit den lib;};
	local = import ../_lib/local.nix;
	secretLib = import ../_lib/secrets.nix {inherit lib;};
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
			den.aspects.email
		];
		userHomeManager = {...}: {
			programs.nushell.extraConfig = ''
				if $nu.is-interactive and ('SSH_CONNECTION' in ($env | columns)) and ('ZELLIJ' not-in ($env | columns)) {
					try {
						zellij attach -c main
						exit
					} catch {
						print "zellij auto-start failed; staying in shell"
					}
				}
			'';
		};
		hostIncludes = [
			den.aspects.host-nixos-base
			den.aspects.opencode-api-key
			den.aspects.ynab-api-key
			den.aspects.paperless
			den.aspects.syncthing
		];
		nixos = {pkgs, ...}: {
			networking.hostName = host;

			environment.systemPackages = [pkgs._1password-cli];

			imports = [
				./_parts/tahani/networking.nix
			];

			sops.secrets.tahani-email-password =
				secretLib.mkUserBinarySecret {
					name = "tahani-email-password";
					sopsFile = ../../secrets/tahani-email-password;
				};

			virtualisation.docker.enable = true;
			users.users.${local.user.name}.extraGroups = [
				"docker"
				"paperless"
			];

			systemd.tmpfiles.rules = [
				"d /var/lib/paperless/consume 2775 paperless paperless -"
				"d /var/lib/paperless/consume/inbox-triage 2775 paperless paperless -"
			];
			swapDevices = [
				{
					device = "/swapfile";
					size = 16 * 1024;
				}
			];
		};
	}
