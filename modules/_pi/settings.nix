{...}: let
	theme = (import ../_lib/theme.nix).catppuccinLatte;
in {
	theme = theme.piThemeName;
	quietStartup = true;
	defaultProvider = "openai-codex";
	defaultModel = "gpt-5.5";
	defaultThinkingLevel = "medium";
	transport = "websocket-cached";
	packages = [
		theme.piPackage
		"npm:pi-mcp-adapter"
		"npm:pi-better-openai"
		"npm:@ff-labs/pi-fff"
		"npm:@juicesharp/rpiv-ask-user-question"
		"npm:@juicesharp/rpiv-todo"
	];
}
