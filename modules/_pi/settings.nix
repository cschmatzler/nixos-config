{
	config,
	pkgs,
}: {
	theme = "rose-pine-dawn";
	quietStartup = true;
	defaultProvider = "openai-codex";
	defaultModel = "gpt-5.4";
	defaultThinkingLevel = "xhigh";
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
		{
			source = "${pkgs.pi-harness}/lib/node_modules/@aliou/pi-harness";
			extensions = ["extensions/breadcrumbs/index.ts"];
			skills = [];
			prompts = [];
			themes = [];
		}
		"https://github.com/ShpetimA/pi-fff"
		"${config.home.homeDirectory}/Projects/Personal/pi-supermemory"
	];
}
