{
	inputs,
	lib,
	...
}: let
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
		piPackages = {
			".pi/agent/extensions/pi-mcp-adapter" = {
				force = true;
				source = "${pkgs.pi-mcp-adapter}/lib/node_modules/pi-mcp-adapter";
			};
			".pi/agent/themes" = {
				source = "${inputs.pi-rose-pine}/themes";
				recursive = true;
			};
		};
		piExtensions = {
			".pi/agent/extensions/no-git.ts".source = ./_pi/extensions/no-git.ts;
			".pi/agent/extensions/review.ts".source = ./_pi/extensions/review.ts;
			".pi/agent/extensions/session-name.ts".source = ./_pi/extensions/session-name.ts;
		};
		piSkills = {
			".pi/agent/skills/jujutsu/SKILL.md".source = ./_pi/skills/jujutsu/SKILL.md;
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
						inherit config pkgs;
					});
			".pi/agent/mcp.json".source =
				jsonFormat.generate "pi-agent-mcp.json" (import ./_pi/mcp.nix {
						inherit lib pkgs;
					});
		};
	in {
		home.packages = [
			inputs'.llm-agents.packages.pi
			pkgs.cog-cli
			pkgs.uv
			pkgs.python314
			pkgs.python314Packages.greenlet
		];

		programs.nushell.extraEnv =
			lib.mkAfter ''
				if ("${opencodeSecretPath}" | path exists) {
					$env.OPENCODE_API_KEY = (open --raw "${opencodeSecretPath}" | str trim)
				}

				if ("${ynabSecretPath}" | path exists) {
					$env.YNAB_API_KEY = (open --raw "${ynabSecretPath}" | str trim)
				}
			'';

		home.file =
			{
				"AGENTS.md".source = ./_pi/AGENTS.md;
			}
			// piPackages
			// piExtensions
			// piSkills
			// piGeneratedConfigs;
	};
}
