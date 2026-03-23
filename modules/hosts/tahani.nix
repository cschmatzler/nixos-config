{den, ...}: {
	den.hosts.x86_64-linux.tahani.users.cschmatzler.aspect = "tahani-cschmatzler";

	den.aspects.tahani-cschmatzler = {
		includes = [
			den.aspects.user-workstation
			den.aspects.user-personal
			den.aspects.email
		];

		homeManager = {
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
	};

	den.aspects.tahani.includes = [
		(den.lib.perHost {
				includes = [den.aspects.host-nixos-base];

				nixos = {...}: {
					imports = [
						./_parts/tahani/adguardhome.nix
						./_parts/tahani/cache.nix
						./_parts/tahani/networking.nix
						./_parts/tahani/paperless.nix
					];

					networking.hostName = "tahani";

					sops.secrets = {
						opencode-api-key = {
							sopsFile = ../../secrets/opencode-api-key;
							format = "binary";
							owner = "cschmatzler";
							path = "/run/secrets/opencode-api-key";
						};
						tahani-paperless-password = {
							sopsFile = ../../secrets/tahani-paperless-password;
							format = "binary";
							path = "/run/secrets/tahani-paperless-password";
						};
						tahani-paperless-gpt-env = {
							sopsFile = ../../secrets/tahani-paperless-gpt-env;
							format = "binary";
							path = "/run/secrets/tahani-paperless-gpt-env";
						};
						tahani-email-password = {
							sopsFile = ../../secrets/tahani-email-password;
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
	];
}
