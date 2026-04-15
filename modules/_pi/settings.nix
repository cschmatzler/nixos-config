{
	config,
	pkgs,
}: {
	theme = "rose-pine-dawn";
	quietStartup = true;
	hideThinkingBlock = true;
	defaultProvider = "openai-codex";
	defaultModel = "gpt-5.3-codex";
	defaultThinkingLevel = "xhigh";
	packages = [
		{
			source = "${pkgs.pi-agent-stuff}/lib/node_modules/mitsupi";
			extensions = [
				"pi-extensions/answer.ts"
				"pi-extensions/context.ts"
				"pi-extensions/multi-edit.ts"
				"pi-extensions/todos.ts"
			];
			skills = [];
			prompts = [];
			themes = [];
		}
		{
			source = "${pkgs.pi-harness}/lib/node_modules/@aliou/pi-harness";
			extensions = ["extensions/breadcrumbs/index.ts"];
			skills = [];
			prompts = [];
			themes = [];
		}
		"${config.home.homeDirectory}/Projects/Personal/pi-supermemory"
	];
}
