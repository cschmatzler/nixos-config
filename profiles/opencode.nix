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
			plugin = ["oh-my-opencode@3.10.0" "opencode-anthropic-auth"];
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
		"opencode/oh-my-opencode.json".text =
			builtins.toJSON {
				"$schema" = "https://raw.githubusercontent.com/code-yeongyu/oh-my-opencode/master/assets/oh-my-opencode.schema.json";
				git_master = {
					commit_footer = false;
					include_co_authored_by = false;
				};
			};
	};
}
