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
			homeManager = {
				config,
				inputs',
				...
			}: let
				opencode = inputs'.llm-agents.packages.opencode;
			in {
				programs.opencode.settings.permission.external_directory = {
					"/tmp/himalaya-triage/*" = "allow";
					"/var/lib/paperless/consume/inbox-triage/*" = "allow";
				};

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

				systemd.user.services.opencode-inbox-triage = {
					Unit = {
						Description = "OpenCode inbox triage";
					};
					Service = {
						Type = "oneshot";
						ExecStart = "${opencode}/bin/opencode run --command inbox-triage --model opencode-go/glm-5";
						Environment = "PATH=${config.home.profileDirectory}/bin:/run/current-system/sw/bin";
					};
				};

				systemd.user.timers.opencode-inbox-triage = {
					Unit = {
						Description = "Run OpenCode inbox triage every 12 hours";
					};
					Timer = {
						OnCalendar = "*-*-* 0/12:00:00";
						Persistent = true;
					};
					Install = {
						WantedBy = ["timers.target"];
					};
				};
			};
		})
	(hostLib.mkPerHostAspect {
			inherit host;
			includes = [
				den.aspects.host-nixos-base
				den.aspects.opencode-api-key
				den.aspects.adguardhome
				den.aspects.cache
				den.aspects.notability
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
