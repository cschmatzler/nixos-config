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
	lib.recursiveUpdate
	(hostLib.mkUserHost {
			system = hostMeta.system;
			inherit host;
			user = local.user.name;
			includes = [
				den.aspects.user-workstation
				den.aspects.user-personal
				den.aspects.email
			];
			homeManager = {...}: {
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
		})
	(hostLib.mkPerHostAspect {
			inherit host;
			includes = [
				den.aspects.host-nixos-base
				den.aspects.opencode-api-key
				den.aspects.adguardhome
				den.aspects.cache
				den.aspects.paperless
			];
			nixos = {...}: {
				imports = [
					./_parts/tahani/networking.nix
				];

				networking.hostName = host;

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
		})
