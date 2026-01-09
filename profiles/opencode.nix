{
	inputs,
	pkgs,
	...
}: {
	programs.opencode = {
		enable = true;
		package = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
		settings = {
			theme = "catppuccin";
			plugin = [
				"oh-my-opencode@3.0.0-beta.2"
			];
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
		};
	};

	home.file.".config/opencode/oh-my-opencode.json".text =
		builtins.toJSON {
			google_auth = false;
			agents = {
				sisyphus = {
					model = "opencode/claude-opus-4-5";
				};
				orchestrator-sisyphus = {
					model = "opencode/claude-opus-4-5";
				};
				"Prometheus (Planner)" = {
					model = "opencode/claude-opus-4-5";
				};
				"Metis (Plan Consultant)" = {
					model = "opencode/claude-opus-4-5";
				};
				"Momus (Plan Reviewer)" = {
					model = "opencode/gpt-5.2";
				};
				momus = {
					model = "opencode/gpt-5.2";
				};
				explore = {
					model = "opencode/minimax-m2.1-free";
				};
				oracle = {
					model = "opencode/gpt-5.2";
				};
				frontend-ui-ux-engineer = {
					model = "opencode/gemini-3-pro";
				};
				document-writer = {
					model = "opencode/gemini-3-flash";
				};
				multimodal-looker = {
					model = "opencode/gemini-3-flash";
				};
			};
			categories = {
				general = {
					model = "opencode/claude-opus-4-5";
				};
				visual = {
					model = "opencode/gemini-3-pro";
				};
				business-logic = {
					model = "opencode/gpt-5.2";
				};
			};
			disabled_hooks = ["startup-toast" "background-notification" "session-notification"];
		};
}
