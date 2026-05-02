{config}: {
	theme = "rose-pine-dawn";
	quietStartup = true;
	defaultProvider = "openai-codex";
	defaultModel = "gpt-5.5";
	defaultThinkingLevel = "medium";
	transport = "websocket-cached";
	packages = [
		{
			source = "npm:mitsupi";
			extensions = [
				"extensions/answer.ts"
				"extensions/context.ts"
				"extensions/multi-edit.ts"
				"extensions/todos.ts"
			];
			skills = [];
			prompts = [];
			themes = [];
		}
		"npm:pi-mcp-adapter"
		"npm:@zenobius/pi-rose-pine"
		"npm:@ff-labs/pi-fff"
		"${config.home.homeDirectory}/Projects/Personal/codex-supermemory"
	];
}
