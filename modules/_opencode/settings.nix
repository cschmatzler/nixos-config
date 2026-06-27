{mcp, ...}: {
	"$schema" = "https://opencode.ai/config.json";
	model = "openai/gpt-5.5";
	small_model = "openai/gpt-5-nano";
	autoupdate = false;
	share = "manual";
	inherit mcp;
	plugin = [
		"opencode-supermemory@latest"
	];
	permission.skill = {
		"customize-opencode" = "allow";
		"wrdn-*" = "allow";
	};
}
