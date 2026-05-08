{lib, ...}: let
	local = import ./_lib/local.nix;
	inherit (local) secretPath;
	secretLib = import ./_lib/secrets.nix {inherit lib;};
	opencodeSecretPath = secretPath "opencode-api-key";
	ynabSecretPath = secretPath "ynab-api-key";
in {
	den.aspects.opencode-api-key.os = {
		sops.secrets.opencode-api-key =
			secretLib.mkUserBinarySecret {
				name = "opencode-api-key";
				sopsFile = ../secrets/opencode-api-key;
			};
	};

	den.aspects.ynab-api-key.os = {
		sops.secrets.ynab-api-key =
			secretLib.mkUserBinarySecret {
				name = "ynab-api-key";
				sopsFile = ../secrets/ynab-api-key;
			};
	};

	den.aspects.ai-tools.homeManager = {
		config,
		lib,
		pkgs,
		inputs',
		...
	}: let
		jsonFormat = pkgs.formats.json {};
		piExtensions = {
			".pi/agent/extensions/answer.ts".source = ./_pi/extensions/answer.ts;
			".pi/agent/extensions/no-git.ts".source = ./_pi/extensions/no-git.ts;
			".pi/agent/extensions/review.ts".source = ./_pi/extensions/review.ts;
			".pi/agent/extensions/session-name.ts".source = ./_pi/extensions/session-name.ts;
		};
		piSkills = {
			".pi/agent/skills/wrdn-authz" = {
				source = ./_pi/skills/warden-skills/wrdn-authz;
				recursive = true;
			};
			".pi/agent/skills/wrdn-code-execution" = {
				source = ./_pi/skills/warden-skills/wrdn-code-execution;
				recursive = true;
			};
			".pi/agent/skills/wrdn-data-exfil" = {
				source = ./_pi/skills/warden-skills/wrdn-data-exfil;
				recursive = true;
			};
			".pi/agent/skills/wrdn-gha-workflows" = {
				source = ./_pi/skills/warden-skills/wrdn-gha-workflows;
				recursive = true;
			};
			".pi/agent/skills/wrdn-pii" = {
				source = ./_pi/skills/warden-skills/wrdn-pii;
				recursive = true;
			};
		};
		piGeneratedConfigs = {
			".pi/agent/settings.json".source =
				jsonFormat.generate "pi-agent-settings.json" (import ./_pi/settings.nix {
						inherit config;
					});
			".pi/agent/mcp.json".source =
				jsonFormat.generate "pi-agent-mcp.json" (import ./_pi/mcp.nix {
						inherit lib pkgs;
					});
		};
	in {
		home.packages = [
			inputs'.llm-agents.packages.codex
			inputs'.llm-agents.packages.pi
			pkgs.cog-cli
			pkgs.hunkdiff
			pkgs.uv
			pkgs.python314
			pkgs.python314Packages.greenlet
		];

		programs.fish.shellInit =
			lib.mkAfter ''
				set -gx NPM_CONFIG_PREFIX "${config.home.homeDirectory}/.npm-global"

				if test -f "${opencodeSecretPath}"
					set -gx OPENCODE_API_KEY (string trim -- (cat "${opencodeSecretPath}"))
				end

				if test -f "${ynabSecretPath}"
					set -gx YNAB_API_KEY (string trim -- (cat "${ynabSecretPath}"))
				end
			'';

		programs.opencode = {
			enable = true;
			package = inputs'.llm-agents.packages.opencode;
			settings = {
				model = "openai/gpt-5.5";
				small_model = "openai/gpt-5.4-mini";
				plugin = ["opencode-supermemory"];
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
					explore = {
						model = "openai/gpt-5.4-mini";
					};
				};
				instructions = [
					"CLAUDE.md"
					"AGENT.md"
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

		systemd.user.services.opencode-server = {
			Unit = {
				Description = "OpenCode AI server";
				After = ["default.target"];
			};
			Service = {
				ExecStart = "${inputs'.llm-agents.packages.opencode}/bin/opencode serve --port 18822";
				Restart = "on-failure";
				RestartSec = 5;
				Environment = "PATH=${pkgs.lib.makeBinPath [inputs'.llm-agents.packages.opencode pkgs.coreutils pkgs.nodejs_24 pkgs.fish]}:/run/current-system/sw/bin";
			};
			Install = {
				WantedBy = ["default.target"];
			};
		};

		xdg.configFile = {
			"opencode/command" = {
				source = ./_opencode/command;
				recursive = true;
			};
			"opencode/skill" = {
				source = ./_opencode/skill;
				recursive = true;
			};
			"opencode/AGENTS.md".source = ./_opencode/AGENTS.md;
			"opencode/tui.json".source = ./_opencode/tui.json;
		};

		home.file =
			{
				"AGENTS.md".source = ./_pi/AGENTS.md;
			}
			// piExtensions
			// piSkills
			// piGeneratedConfigs;
	};
}
