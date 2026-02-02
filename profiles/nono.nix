{pkgs, ...}: {
	home.packages = with pkgs; [
		nono
	];

	xdg.configFile."nono/profiles/opencode.toml".text = ''
		[meta]
		name = "opencode"
		version = "1.0.0"
		description = "OpenCode AI agent"

		[filesystem]
		allow = ["$WORKDIR"]
		read = ["$XDG_CONFIG_HOME/opencode"]

		[network]
		block = false
	'';
}
