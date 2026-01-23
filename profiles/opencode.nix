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
			small_model = "opencode/glm-4.7";
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
				explore = {
					model = "opencode/glm-4.7";
				};
			};
			instructions = [
				"CLAUDE.md"
				"AGENT.md"
				"AGENTS.md"
			];
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
