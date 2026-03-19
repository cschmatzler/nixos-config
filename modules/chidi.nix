{den, ...}: {
	den.hosts.aarch64-darwin.chidi.users.cschmatzler.aspect = "chidi-cschmatzler";

	den.aspects.chidi-cschmatzler = {
		includes = [
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
			den.aspects.desktop
		];

		homeManager = {...}: {
			programs.home-manager.enable = true;
			fonts.fontconfig.enable = true;
			programs.git.settings.user.email = "christoph@tuist.dev";
		};
	};

	den.aspects.chidi.includes = [
		(den.lib.perHost {
				includes = [
					den.aspects.darwin-system
					den.aspects.core
					den.aspects.tailscale
				];

				darwin = {pkgs, ...}: {
					networking.hostName = "chidi";
					networking.computerName = "chidi";

					environment.systemPackages = with pkgs; [
						slack
					];
				};
			})
	];
}
