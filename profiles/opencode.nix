{
	inputs,
	pkgs,
	...
}: {
	programs.opencode = {
		enable = true;
		package = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
		settings = {
			model = "opencode/claude-opus-4-5";
			theme = "catppuccin";
			plugin = [
				"oh-my-opencode@3.0.0-beta.6"
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
				Sisyphus = {
					model = "opencode/claude-opus-4-5";
				};
				"Sisyphus-Junior" = {
					model = "opencode/claude-sonnet-4-5";
				};
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
				librarian = {
					model = "opencode/glm-4.7-free";
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
				"visual-engineering" = {
					model = "opencode/gemini-3-pro";
				};
				ultrabrain = {
					model = "opencode/gpt-5.2";
				};
				artistry = {
					model = "opencode/gemini-3-pro";
				};
				quick = {
					model = "opencode/claude-haiku-4-5";
				};
				"most-capable" = {
					model = "opencode/claude-opus-4-5";
				};
				writing = {
					model = "opencode/gemini-3-flash";
				};
				general = {
					model = "opencode/claude-sonnet-4-5";
				};
				visual = {
					model = "opencode/gemini-3-pro";
				};
				"business-logic" = {
					model = "opencode/gpt-5.2";
				};
			};

			disabled_hooks = ["startup-toast" "background-notification" "session-notification"];
		};
}
