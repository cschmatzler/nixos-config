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
			settings = {
				model = "openai/gpt-5.4";
				small_model = "openai/gpt-5.1-mini";
				theme = "rosepine";
				plugin = [
					"opencode-claude-auth"
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
						mosh = "ask";
						"mosh *" = "ask";
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
				build = {
					disable = true;
				};
				plan = {
					disable = true;
				};
				explore = {
					model = "openai/gpt-5.1-mini";
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
			"opencode/plugin" = {
				source = ./_opencode/plugin;
				recursive = true;
			};
			"opencode/AGENTS.md".source = ./_opencode/AGENTS.md;
			"opencode/tui.json".source = ./_opencode/tui.json;
		};
	};
}
