{den, ...}: {
	den.hosts.aarch64-darwin.jason.users.cschmatzler.aspect = "jason-cschmatzler";

	den.aspects.jason-cschmatzler = {
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
			programs.git.settings.user.email = "christoph@schmatzler.com";
		};
	};

	den.aspects.jason.includes = [
		(den.lib.perHost {
				includes = [
					den.aspects.darwin-system
					den.aspects.core
					den.aspects.tailscale
				];

				darwin = {...}: {
					networking.hostName = "jason";
					networking.computerName = "jason";
				};
			})
	];
}
