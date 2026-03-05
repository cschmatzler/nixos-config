{
	inputs,
	pkgs,
	...
}: {
	programs.opencode = {
		enable = true;
		package = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
		settings = {
			model = "anthropic/claude-opus-4-6";
			small_model = "anthropic/claude-haiku-4-5";
			theme = "catppuccin";
			plugin = ["oh-my-opencode@latest" "opencode-anthropic-auth@latest"];
			permission = {
				read = {
					"*" = "allow";
					"*.env" = "deny";
					"*.env.*" = "deny";
					"*.envrc" = "deny";
					"secrets/*" = "deny";
				};
			};
			agent = {
				plan = {
					model = "anthropic/claude-opus-4-6";
				};
				explore = {
					model = "anthropic/claude-haiku-4-5";
				};
			};
			instructions = [
				"CLAUDE.md"
				"AGENT.md"
				# "AGENTS.md"
				"AGENTS.local.md"
			];
			formatter = {
				mix = {
					disabled = true;
				};
			};
			mcp = {
				opensrc = {
					enabled = true;
					type = "local";
					command = ["bunx" "opensrc-mcp"];
				};
			};
		};
	};

	xdg.configFile = {
		"opencode/agent" = {
			source = ./opencode/agent;
			recursive = true;
		};
		"opencode/command" = {
			source = ./opencode/command;
			recursive = true;
		};
		"opencode/skill" = {
			source = ./opencode/skill;
			recursive = true;
		};
		"opencode/tool" = {
			source = ./opencode/tool;
			recursive = true;
		};
		"opencode/plugin" = {
			source = ./opencode/plugin;
			recursive = true;
		};
		"opencode/AGENTS.md".source = ./opencode/AGENTS.md;
		"opencode/oh-my-opencode.json".text =
			builtins.toJSON {
				"$schema" = "https://raw.githubusercontent.com/code-yeongyu/oh-my-opencode/master/assets/oh-my-opencode.schema.json";
				disabled_skills = ["playwright" "dev-browser"];
				git_master = {
					commit_footer = false;
					include_co_authored_by = false;
				};
				runtime_fallback = true;
				agents = {
					explore = {
						model = "opencode-go/minimax-m2.5";
						fallback_models = ["anthropic/claude-haiku-4-5"];
					};
					librarian = {
						model = "opencode-go/minimax-m2.5";
						fallback_models = ["opencode-go/glm-5"];
					};
					sisyphus = {
						fallback_models = ["opencode-go/kimi-k2.5" "opencode-go/glm-5"];
					};
				};
				categories = {
					"visual-engineering" = {
						fallback_models = ["opencode-go/glm-5" "opencode-go/kimi-k2.5"];
					};
					ultrabrain = {
						fallback_models = ["opencode-go/kimi-k2.5" "opencode-go/glm-5"];
					};
					deep = {
						fallback_models = ["opencode-go/kimi-k2.5" "opencode-go/glm-5"];
					};
					artistry = {
						fallback_models = ["opencode-go/kimi-k2.5" "opencode-go/glm-5"];
					};
					quick = {
						fallback_models = ["opencode-go/minimax-m2.5"];
					};
					"unspecified-low" = {
						fallback_models = ["opencode-go/minimax-m2.5" "opencode-go/kimi-k2.5"];
					};
					"unspecified-high" = {
						fallback_models = ["opencode-go/kimi-k2.5" "opencode-go/glm-5"];
					};
					writing = {
						fallback_models = ["opencode-go/kimi-k2.5" "opencode-go/minimax-m2.5"];
					};
				};
			};
	};
}
