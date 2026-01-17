{
	inputs,
	pkgs,
	...
}: {
	programs.opencode = {
		enable = true;
		package = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
		settings = {
			model = "opencode/gpt-5.2";
			theme = "catppuccin";
			instructions = [
				"CLAUDE.md"
				"AGENT.md"
				"AGENTS.md"
			];
			formatter = {
				mix = {
					disabled = true;
				};
			};
			agent = {
				explore = {model = "opencode/glm-4-7";};
			};
		};
	};
}
