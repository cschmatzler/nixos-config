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
				"oh-my-opencode@2.14.0"
				"opencode-antigravity-auth@1.2.7"
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
			provider = {
				google = {
					models = {
						antigravity-gemini-3-pro-high = {
							name = "Gemini 3 Pro High (Antigravity)";
							limit = {
								context = 1048576;
								output = 65535;
							};
							modalities = {
								input = ["text" "image" "pdf"];
								output = ["text"];
							};
						};
						antigravity-gemini-3-flash = {
							name = "Gemini 3 Flash (Antigravity)";
							limit = {
								context = 1048576;
								output = 65536;
							};
							modalities = {
								input = ["text" "image" "pdf"];
								output = ["text"];
							};
						};
					};
				};
			};
		};
	};

	home.file.".config/opencode/oh-my-opencode.json".text =
		builtins.toJSON {
			google_auth = false;
			agents = {
				explore = {
					model = "opencode/minimax-m2.1-free";
				};
				oracle = {
					model = "opencode/gpt-5.2";
				};
				frontend-ui-ux-engineer = {
					model = "google/antigravity-gemini-3-pro-high";
				};
				document-writer = {
					model = "google/antigravity-gemini-3-flash";
				};
				multimodal-looker = {
					model = "google/antigravity-gemini-3-flash";
				};
			};
			disabled_hooks = ["startup-toast" "background-notification" "session-notification"];
			disabled_mcps = ["websearch_exa"];
		};
}
