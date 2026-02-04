{
	inputs,
	pkgs,
	...
}: {
	home.sessionVariables = {
		OPENCODE_ENABLE_EXA = 1;
		OPENCODE_EXPERIMENTAL_LSP_TOOL = 1;
		# OPENCODE_EXPERIMENTAL_MARKDOWN = 1;
		OPENCODE_EXPERIMENTAL_PLAN_MODE = 1;
		OPENCODE_EXPERIMENTAL_FILE_WATCHER = 1;
	};

	programs.opencode = {
		enable = true;
		package = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
		settings = {
			model = "opencode/claude-opus-4-5";
			small_model = "opencode/minimax-m2.1";
			theme = "catppuccin";
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
					model = "opencode/gpt-5.2-codex";
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
				appsignal = {
					enabled = true;
					type = "local";
					command = [
						"docker"
						"run"
						"-i"
						"--rm"
						"-e"
						"APPSIGNAL_API_KEY"
						"appsignal/mcp"
					];
					environment = {
						APPSIGNAL_API_KEY = "{env:APPSIGNAL_API_KEY}";
					};
				};
				overseer = {
					enabled = true;
					type = "local";
					command = ["npx" "-y" "@dmmulroy/overseer" "mcp"];
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
