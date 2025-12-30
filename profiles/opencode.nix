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
				"oh-my-opencode"
				"opencode-antigravity-auth"
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
						gemini-3-pro-high = {
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
						gemini-3-pro-low = {
							name = "Gemini 3 Pro Low (Antigravity)";
							limit = {
								context = 1048576;
								output = 65535;
							};
							modalities = {
								input = ["text" "image" "pdf"];
								output = ["text"];
							};
						};
						gemini-3-flash = {
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
						claude-sonnet-4-5 = {
							name = "Claude Sonnet 4.5 (Antigravity)";
							limit = {
								context = 200000;
								output = 64000;
							};
							modalities = {
								input = ["text" "image" "pdf"];
								output = ["text"];
							};
						};
						claude-sonnet-4-5-thinking = {
							name = "Claude Sonnet 4.5 Thinking (Antigravity)";
							limit = {
								context = 200000;
								output = 64000;
							};
							modalities = {
								input = ["text" "image" "pdf"];
								output = ["text"];
							};
						};
						claude-opus-4-5-thinking = {
							name = "Claude Opus 4.5 Thinking (Antigravity)";
							limit = {
								context = 200000;
								output = 64000;
							};
							modalities = {
								input = ["text" "image" "pdf"];
								output = ["text"];
							};
						};
						gpt-oss-120b-medium = {
							name = "GPT-OSS 120B Medium (Antigravity)";
							limit = {
								context = 131072;
								output = 32768;
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
			"$schema" = "https://raw.githubusercontent.com/code-yeongyu/oh-my-opencode/master/assets/oh-my-opencode.schema.json";
			google_auth = false;
			experimental = {
				dcp_for_compaction = true;
			};
			agents = {
				explore = {
					model = "opencode/minimax-free";
				};
				oracle = {
					model = "opencode/gpt-5.2";
				};
				frontend-ui-ux-engineer = {
					model = "google/gemini-3-pro-high";
				};
				document-writer = {
					model = "google/gemini-3-flash";
				};
				multimodal-looker = {
					model = "google/gemini-3-flash";
				};
			};
			disabled_hooks = ["startup-toast" "background-notification" "session-notification"];
		};
}
