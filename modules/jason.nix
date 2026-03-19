{den, ...}: {
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
					den.aspects.desktop
				];

				homeManager = {...}: {
					fonts.fontconfig.enable = true;
					programs.git.settings.user.email = "christoph@schmatzler.com";
				};
			})
	];
}
