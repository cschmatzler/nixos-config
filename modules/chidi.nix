{den, ...}: {
	den.aspects.chidi.includes = [
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
		den.aspects.secrets
	];

	den.aspects.chidi.darwin = {pkgs, ...}: {
		networking.hostName = "chidi";
		networking.computerName = "chidi";

		environment.systemPackages = with pkgs; [
			slack
		];
	};

	den.aspects.chidi.homeManager = {...}: {
		fonts.fontconfig.enable = true;
		programs.git.settings.user.email = "christoph@tuist.dev";
	};
}
