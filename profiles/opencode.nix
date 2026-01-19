{
	inputs,
	pkgs,
	...
}: {
	programs.opencode = {
		enable = true;
		package = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
		settings = {
			model = "opencode/gpt-5-2-codex";
			small_model = "opencode/gpt-5-1-codex-mini";
			theme = "catppuccin";
			permission = "allow";
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
				explore = {
					model = "opencode/minimax-m2.1-free";
				};
			};
		};
	};
}
