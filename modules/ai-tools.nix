{
	inputs,
	lib,
	...
}: let
	local = import ./_lib/local.nix;
	inherit (local) secretPath;
	secretLib = import ./_lib/secrets.nix {inherit lib;};
	opencodeSecretPath = secretPath "opencode-api-key";
in {
	den.aspects.opencode-api-key.os = {
		sops.secrets.opencode-api-key =
			secretLib.mkUserBinarySecret {
				name = "opencode-api-key";
				sopsFile = ../secrets/opencode-api-key;
			};
	};

	den.aspects.ai-tools.homeManager = {
		lib,
		pkgs,
		inputs',
		...
	}: {
		home.packages = [
			inputs'.llm-agents.packages.claude-code
			inputs'.llm-agents.packages.pi
			pkgs.cog-cli
		];

		programs.nushell.extraEnv =
			lib.mkAfter ''
				if ("${opencodeSecretPath}" | path exists) {
					$env.OPENCODE_API_KEY = (open --raw "${opencodeSecretPath}" | str trim)
				}
			'';

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
