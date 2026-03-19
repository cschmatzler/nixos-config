{den, ...}: {
	den.aspects.tahani.includes = [
		(den.lib.perHost {
				includes = [
					den.aspects.nixos-system
					den.aspects.core
					den.aspects.openssh
					den.aspects.tailscale
				];

				nixos = {...}: {
					imports = [
						./_hosts/tahani/adguardhome.nix
						./_hosts/tahani/cache.nix
						./_hosts/tahani/networking.nix
						./_hosts/tahani/paperless.nix
					];

					networking.hostName = "tahani";

					sops.secrets = {
						tahani-paperless-password = {
							sopsFile = ../secrets/tahani-paperless-password;
							format = "binary";
							path = "/run/secrets/tahani-paperless-password";
						};
						tahani-paperless-gpt-env = {
							sopsFile = ../secrets/tahani-paperless-gpt-env;
							format = "binary";
							path = "/run/secrets/tahani-paperless-gpt-env";
						};
						tahani-email-password = {
							sopsFile = ../secrets/tahani-email-password;
							format = "binary";
							owner = "cschmatzler";
							path = "/run/secrets/tahani-email-password";
						};
					};
					virtualisation.docker.enable = true;
					users.users.cschmatzler.extraGroups = ["docker" "paperless"];

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
		(den.lib.perUser {
				includes = [
					den.aspects.cschmatzler
					den.aspects.shell
					den.aspects.ssh-client
					den.aspects.terminal
					den.aspects.atuin
					den.aspects.dev-tools
					den.aspects.neovim
					den.aspects.ai-tools
					den.aspects.secrets
					den.aspects.zellij
					den.aspects.zk
					den.aspects.email
				];

				homeManager = {
					config,
					inputs',
					...
				}: let
					opencode = inputs'.llm-agents.packages.opencode;
				in {
					programs.git.settings.user.email = "christoph@schmatzler.com";

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
	];
}
