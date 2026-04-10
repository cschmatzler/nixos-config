{inputs, ...}: let
	local = import ./_lib/local.nix;
	inherit (local) secretPath;
	opencodeSecretPath = secretPath "opencode-api-key";
in {
	den.aspects.ai-tools.homeManager = {
		lib,
		pkgs,
		inputs',
		...
	}: {
		home.packages = [
			inputs'.llm-agents.packages.claude-code
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
			tui = {
				theme = "rosepine";
			};
			settings = {
				model = "openai/gpt-5.4";
				small_model = "openai/gpt-5.1-codex-mini";
				plugin = [
					"opencode-supermemory@2.0.6"
				];
				permission = {
					external_directory = {
						"*" = "allow";
						"**/.gnupg/**" = "deny";
						"**/.ssh/**" = "deny";
						"~/.config/gh/hosts.yml" = "deny";
						"~/.config/sops/age/keys.txt" = "deny";
						"~/.local/share/opencode/mcp-auth.json" = "deny";
						"/etc/ssh/ssh_host_*" = "deny";
						"/run/secrets/*" = "deny";
					};
					bash = {
						"*" = "allow";
						env = "deny";
						"env *" = "deny";
						printenv = "deny";
						"printenv *" = "deny";
						"export *" = "deny";
						"gh auth *" = "deny";
						ssh = "ask";
						"ssh *" = "ask";
						"cat *.env" = "deny";
						"cat *.env.*" = "deny";
						"cat **/.env" = "deny";
						"cat **/.env.*" = "deny";
						"cat *.envrc" = "deny";
						"cat **/.envrc" = "deny";
						"cat .dev.vars" = "deny";
						"cat **/.dev.vars" = "deny";
						"cat *.pem" = "deny";
						"cat *.key" = "deny";
						"cat **/.gnupg/**" = "deny";
						"cat **/.ssh/**" = "deny";
						"cat ~/.config/gh/hosts.yml" = "deny";
						"cat ~/.config/sops/age/keys.txt" = "deny";
						"cat ~/.local/share/opencode/mcp-auth.json" = "deny";
						"cat /etc/ssh/ssh_host_*" = "deny";
						"cat /run/secrets/*" = "deny";
					};
					edit = {
						"*" = "allow";
						"**/.gnupg/**" = "deny";
						"**/.ssh/**" = "deny";
						"**/secrets/**" = "deny";
						"secrets/*" = "deny";
						"~/.config/gh/hosts.yml" = "deny";
						"~/.config/sops/age/keys.txt" = "deny";
						"~/.local/share/opencode/mcp-auth.json" = "deny";
						"/etc/ssh/ssh_host_*" = "deny";
						"/run/secrets/*" = "deny";
					};
					glob = "allow";
					grep = "allow";
					list = "allow";
					lsp = "allow";
					question = "allow";
					read = {
						"*" = "allow";
						"*.env" = "deny";
						"*.env.*" = "deny";
						"*.envrc" = "deny";
						"**/.env" = "deny";
						"**/.env.*" = "deny";
						"**/.envrc" = "deny";
						".dev.vars" = "deny";
						"**/.dev.vars" = "deny";
						"**/.gnupg/**" = "deny";
						"**/.ssh/**" = "deny";
						"*.key" = "deny";
						"*.pem" = "deny";
						"**/secrets/**" = "deny";
						"secrets/*" = "deny";
						"~/.config/gh/hosts.yml" = "deny";
						"~/.config/sops/age/keys.txt" = "deny";
						"~/.local/share/opencode/mcp-auth.json" = "deny";
						"/etc/ssh/ssh_host_*" = "deny";
						"/run/secrets/*" = "deny";
					};
					skill = "allow";
					task = "allow";
					webfetch = "allow";
					websearch = "allow";
					codesearch = "allow";
				};
				agent = {
					explore = {
						model = "openai/gpt-5.1-codex-mini";
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
				};
			};
		};

		xdg.configFile = {
			# "opencode/agent" = {
			# 	source = ./_opencode/agent;
			# 	recursive = true;
			# };
			"opencode/command" = {
				source = ./_opencode/command;
				recursive = true;
			};
			"opencode/skill" = {
				source = ./_opencode/skill;
				recursive = true;
			};
			"opencode/plugin" = {
				source = ./_opencode/plugin;
				recursive = true;
			};
			"opencode/AGENTS.md".source = ./_opencode/AGENTS.md;
		};

		home.file = {
			"AGENTS.md".source = ./_pi/AGENTS.md;
			".pi/agent/extensions/pi-elixir" = {
				source = inputs.pi-elixir;
				recursive = true;
			};
			".pi/agent/extensions/pi-mcp-adapter" = {
				source = "${pkgs.pi-mcp-adapter}/lib/node_modules/pi-mcp-adapter";
				recursive = true;
			};
			".pi/agent/extensions/no-git.ts".source = ./_pi/extensions/no-git.ts;
			".pi/agent/extensions/no-scripting.ts".source = ./_pi/extensions/no-scripting.ts;
			".pi/agent/extensions/review.ts".source = ./_pi/extensions/review.ts;
			".pi/agent/extensions/session-name.ts".source = ./_pi/extensions/session-name.ts;
			".pi/agent/skills/elixir-dev" = {
				source = "${inputs.pi-elixir}/skills/elixir-dev";
				recursive = true;
			};
			".pi/agent/skills/jujutsu/SKILL.md".source = ./_pi/skills/jujutsu/SKILL.md;
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
			".pi/agent/mcp.json".source = ./_pi/mcp.json;
		};
	};
}
