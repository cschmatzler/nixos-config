{...}: let
	theme = (import ../_lib/theme.nix).rosePineDawn;
in {
	theme = theme.piThemeName;
	quietStartup = true;
	defaultProvider = "openai-codex";
	defaultModel = "gpt-5.5";
	defaultThinkingLevel = "medium";
	transport = "websocket-cached";
	packages = [
		"npm:pi-mcp-adapter"
		theme.piPackage
		"npm:pi-better-openai"
	];
}
