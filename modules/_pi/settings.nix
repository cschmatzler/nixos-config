{
	config,
	pkgs,
}: {
	theme = "rose-pine-dawn";
	quietStartup = true;
	defaultProvider = "openai-codex";
	defaultModel = "gpt-5.5";
	defaultThinkingLevel = "medium";
	packages = [
		{
			source = "${pkgs.pi-agent-stuff}/lib/node_modules/mitsupi";
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
		"npm:@ff-labs/pi-fff"
		"${config.home.homeDirectory}/Projects/Personal/codex-supermemory"
	];
}
