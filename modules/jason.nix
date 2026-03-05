{den, ...}: {
	den.aspects.jason.includes = [
		den.aspects.darwin-system
		den.aspects.core
		den.aspects.tailscale
		den.aspects.desktop
		den.aspects.terminal
		den.aspects.atuin
		den.aspects.dev-tools
		den.aspects.neovim
		den.aspects.ai-tools
		den.aspects.zellij
		den.aspects.zk
	];

	den.aspects.jason.darwin = {...}: {
		networking.hostName = "jason";
		networking.computerName = "jason";
	};

	den.aspects.jason.homeManager = {...}: {
		fonts.fontconfig.enable = true;
		programs.git.settings.user.email = "christoph@schmatzler.com";
	};
}
