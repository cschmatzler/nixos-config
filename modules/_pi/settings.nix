{config}: {
	theme = "rose-pine-dawn";
	quietStartup = true;
	defaultProvider = "openai-codex";
	defaultModel = "gpt-5.5";
	defaultThinkingLevel = "medium";
	transport = "websocket-cached";
	packages = [
		"npm:pi-mcp-adapter"
		"npm:@zenobius/pi-rose-pine"
		"npm:@ff-labs/pi-fff"
		"npm:pi-better-openai"
	];
}
