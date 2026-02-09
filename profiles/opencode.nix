{
	inputs,
	pkgs,
	...
}: {
	home.sessionVariables = {
		OPENCODE_ENABLE_EXA = 1;
		OPENCODE_EXPERIMENTAL_LSP_TOOL = 1;
		OPENCODE_EXPERIMENTAL_MARKDOWN = 1;
		OPENCODE_EXPERIMENTAL_PLAN_MODE = 1;
	};

	programs.opencode = {
		enable = true;
		package = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
		settings = {
			model = "anthropic/claude-opus-4-6";
			small_model = "opencode/minimax-m2.1";
			theme = "catppuccin";
			plugin = ["oh-my-opencode" "opencode-anthropic-auth"];
			keybinds = {
				leader = "ctrl+o";
			};
			permission = {
				read = {
					"*" = "allow";
					"*.env" = "deny";
					"*.env.*" = "deny";
					"*.envrc" = "deny";
					"secrets/*" = "deny";
					"~/.local/share/opencode/mcp-auth.json" = "deny";
				};
			};
			agent = {
				plan = {
					model = "anthropic/claude-opus-4-6";
				};
				explore = {
					model = "opencode/minimax-m2.1";
				};
			};
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
			mcp = {
				cog = {
					enabled = true;
					type = "remote";
					url = "https://trycog.ai/mcp";
					headers = {
						Authorization = "Bearer {env:COG_API_TOKEN}";
					};
				};
				context7 = {
					enabled = true;
					type = "remote";
					url = "https://mcp.context7.com/mcp";
				};
				grep_app = {
					enabled = true;
					type = "remote";
					url = "https://mcp.grep.app";
				};
				opensrc = {
					enabled = true;
					type = "local";
					command = ["bunx" "opensrc-mcp"];
				};
				overseer = {
					enabled = true;
					type = "local";
					command = ["${pkgs.overseer}/bin/os" "mcp"];
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
		"opencode/oh-my-opencode.json".text =
			builtins.toJSON {
				"$schema" = "https://raw.githubusercontent.com/code-yeongyu/oh-my-opencode/master/assets/oh-my-opencode.schema.json";
				disabled_mcps = ["websearch" "context7" "grep_app"];
				git_master = {
					commit_footer = false;
					include_co_authored_by = false;
				};
			};
	};
}
