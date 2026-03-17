{
	den.aspects.ai-tools.homeManager = {
		config,
		pkgs,
		inputs',
		...
	}: {
		home.packages = [
			inputs'.llm-agents.packages.claude-code
			pkgs.nono
		];

		home.shellAliases = {
			noc = "nono run -s --allow-cwd --profile opencode --allow ~/.bun --allow ~/.local/share/opensrc --allow ~/.config/jj --network-profile developer --proxy-allow models.dev --proxy-allow chatgpt.com --proxy-allow mcp.grep.app --proxy-allow mcp.context7.com --proxy-allow mcp.exa.ai --proxy-allow mcp.sentry.dev -- opencode";
		};

		programs.opencode = {
			enable = true;
			package = inputs'.llm-agents.packages.opencode;
			settings = {
				model = "anthropic/claude-opus-4-6";
				small_model = "anthropic/claude-haiku-4-5";
				theme = "rosepine";
				plugin = ["opencode-anthropic-auth@latest"];
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
						command = ["node" "/home/cschmatzler/.bun/bin/opensrc-mcp"];
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
					sentry = {
						enabled = true;
						type = "remote";
						url = "https://mcp.sentry.dev/mcp";
						oauth = {};
					};
				};
			};
		};

		systemd.user.services.opencode-server = {
			Unit = {
				Description = "OpenCode AI server";
				After = ["default.target"];
			};
			Service = {
				ExecStart = "${inputs'.llm-agents.packages.opencode}/bin/opencode serve --port 18822 --hostname 0.0.0.0";
				Restart = "on-failure";
				RestartSec = 5;
				Environment = "PATH=${config.home.profileDirectory}/bin:/run/current-system/sw/bin";
			};
			Install = {
				WantedBy = ["default.target"];
			};
		};

		xdg.configFile = {
			"opencode/agent" = {
				source = ./_opencode/agent;
				recursive = true;
			};
			"opencode/command" = {
				source = ./_opencode/command;
				recursive = true;
			};
			"opencode/skill" = {
				source = ./_opencode/skill;
				recursive = true;
			};
			"opencode/tool" = {
				source = ./_opencode/tool;
				recursive = true;
			};
			"opencode/plugin" = {
				source = ./_opencode/plugin;
				recursive = true;
			};
			"opencode/AGENTS.md".source = ./_opencode/AGENTS.md;
		};
	};
}
