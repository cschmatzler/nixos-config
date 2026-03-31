{inputs, ...}: let
	local = import ./_lib/local.nix;
	inherit (local) secretPath;
	opencodeSecretPath = secretPath "opencode-api-key";
in {
	den.aspects.ai-tools.homeManager = {
		config,
		lib,
		pkgs,
		inputs',
		...
	}: {
		home.packages = [
			inputs'.llm-agents.packages.pi
			pkgs.cog-cli
		];

		programs.nushell.extraEnv =
			lib.mkAfter ''
				if ("${opencodeSecretPath}" | path exists) {
					$env.OPENCODE_API_KEY = (open --raw "${opencodeSecretPath}" | str trim)
				}
			'';

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

		home.file = {
			"AGENTS.md".source = ./_ai-tools/AGENTS.md;
			".pi/agent/extensions/pi-elixir" = {
				source = inputs.pi-elixir;
				recursive = true;
			};
			".pi/agent/extensions/pi-mcp-adapter" = {
				source = "${pkgs.pi-mcp-adapter}/lib/node_modules/pi-mcp-adapter";
				recursive = true;
			};
			".pi/agent/extensions/no-git.ts".source = ./_ai-tools/extensions/no-git.ts;
			".pi/agent/extensions/no-scripting.ts".source = ./_ai-tools/extensions/no-scripting.ts;
			".pi/agent/extensions/note-ingest.ts".source = ./_ai-tools/extensions/note-ingest.ts;
			".pi/agent/extensions/review.ts".source = ./_ai-tools/extensions/review.ts;
			".pi/agent/extensions/session-name.ts".source = ./_ai-tools/extensions/session-name.ts;
			".pi/agent/notability" = {
				source = ./_notability;
				recursive = true;
			};
			".pi/agent/skills/elixir-dev" = {
				source = "${inputs.pi-elixir}/skills/elixir-dev";
				recursive = true;
			};
			".pi/agent/skills/jujutsu/SKILL.md".source = ./_ai-tools/skills/jujutsu/SKILL.md;
			".pi/agent/skills/notability-transcribe/SKILL.md".source = ./_ai-tools/skills/notability-transcribe/SKILL.md;
			".pi/agent/skills/notability-normalize/SKILL.md".source = ./_ai-tools/skills/notability-normalize/SKILL.md;
			".pi/agent/themes" = {
				source = "${inputs.pi-rose-pine}/themes";
				recursive = true;
			};
			".pi/agent/settings.json".text =
				builtins.toJSON {
					theme = "rose-pine-dawn";
					quietStartup = true;
					hideThinkingBlock = true;
					defaultProvider = "openai-codex";
					defaultModel = "gpt-5.4";
					defaultThinkingLevel = "high";
					packages = [
						{
							source = "${pkgs.pi-agent-stuff}/lib/node_modules/mitsupi";
							extensions = [
								"pi-extensions/answer.ts"
								"pi-extensions/context.ts"
								"pi-extensions/multi-edit.ts"
								"pi-extensions/todos.ts"
							];
							skills = [];
							prompts = [];
							themes = [];
						}
						{
							source = "${pkgs.pi-harness}/lib/node_modules/@aliou/pi-harness";
							extensions = ["extensions/breadcrumbs/index.ts"];
							skills = [];
							prompts = [];
							themes = [];
						}
					];
				};
			".pi/agent/mcp.json".source = ./_ai-tools/mcp.json;
		};
	};
}
