{den, ...}: {
	den.aspects.tahani.includes = [
		den.aspects.nixos-system
		den.aspects.core
		den.aspects.openssh
		den.aspects.tailscale
		den.aspects.terminal
		den.aspects.email
		den.aspects.atuin
		den.aspects.dev-tools
		den.aspects.neovim
		den.aspects.ai-tools
		den.aspects.zellij
		den.aspects.zk
	];

	den.aspects.tahani.nixos = {...}: {
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
			};
			tahani-email-password = {
				sopsFile = ../secrets/tahani-email-password;
				format = "binary";
				owner = "cschmatzler";
			};
		};
		virtualisation.docker.enable = true;
		users.users.cschmatzler.extraGroups = ["docker"];
		swapDevices = [
			{
				device = "/swapfile";
				size = 16 * 1024;
			}
		];
	};

	den.aspects.tahani.homeManager = {
		pkgs,
		inputs',
		...
	}: let
		opencode = inputs'.llm-agents.packages.opencode;
	in {
		programs.git.settings.user.email = "christoph@schmatzler.com";

		# Auto-start zellij in nushell on tahani (headless server)
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

		# Inbox-triage systemd service
		systemd.user.services.opencode-inbox-triage = {
			Unit = {
				Description = "OpenCode inbox triage";
			};
			Service = {
				Type = "oneshot";
				ExecStart = "${opencode}/bin/opencode run --command inbox-triage";
				Environment = "PATH=${pkgs.himalaya}/bin:${opencode}/bin:${pkgs.coreutils}/bin";
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
}
