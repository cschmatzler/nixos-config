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
					model = "opencode/minimax-m2.1-free";
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
					enabled = false;
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
}
