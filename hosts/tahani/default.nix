{
	config,
	pkgs,
	inputs,
	user,
	hostname,
	...
}: let
	himalaya = config.home-manager.users.${user}.programs.himalaya.package;
	opencode = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
in {
	imports = [
		./adguardhome.nix
		./cache.nix
		./networking.nix
		./paperless.nix
		./secrets.nix
		../../profiles/core.nix
		../../profiles/nixos.nix
		../../profiles/openssh.nix
		../../profiles/tailscale.nix
		inputs.sops-nix.nixosModules.sops
	];

	networking.hostName = hostname;

	home-manager.users.${user} = {
		imports = [
			../../profiles/atuin.nix
			../../profiles/bash.nix
			../../profiles/bat.nix
			../../profiles/direnv.nix
			../../profiles/nushell.nix
			../../profiles/fzf.nix
			../../profiles/git.nix
			../../profiles/himalaya.nix
			../../profiles/mbsync.nix
			../../profiles/home.nix
			../../profiles/jjui.nix
			../../profiles/jujutsu.nix
			../../profiles/lazygit.nix
			../../profiles/mise.nix
			../../profiles/neovim
			../../profiles/opencode.nix
			../../profiles/overseer.nix
			../../profiles/claude-code.nix
			../../profiles/ripgrep.nix
			../../profiles/ssh.nix
			../../profiles/starship.nix
			../../profiles/yazi.nix
			../../profiles/zellij.nix
			../../profiles/zk.nix
			../../profiles/zoxide.nix
			../../profiles/zsh.nix
			inputs.nixvim.homeModules.nixvim
		];

		programs.git.settings.user.email = "christoph@schmatzler.com";

		systemd.user.services.opencode-inbox-triage = {
			Unit = {
				Description = "OpenCode inbox triage";
			};
			Service = {
				Type = "oneshot";
				ExecStart = "${opencode}/bin/opencode run --command inbox-triage";
				Environment = "PATH=${himalaya}/bin:${opencode}/bin";
			};
		};

		systemd.user.timers.opencode-inbox-triage = {
			Unit = {
				Description = "Run OpenCode inbox triage every 10 minutes";
			};
			Timer = {
				OnCalendar = "*:0/10";
				Persistent = true;
			};
			Install = {
				WantedBy = ["timers.target"];
			};
		};
	};

	virtualisation.docker.enable = true;

	users.users.${user}.extraGroups = ["docker"];

	swapDevices = [
		{
			device = "/swapfile";
			size = 16 * 1024;
		}
	];
}
