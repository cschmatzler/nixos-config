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
			plugin = ["opencode-anthropic-auth"];
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
	};
}
