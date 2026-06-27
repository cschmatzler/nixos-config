{...}: {
	den.aspects.opencode.homeManager = {
		lib,
		pkgs,
		inputs',
		...
	}: let
		skills = {
			".config/opencode/skills/wrdn-authz" = {
				source = ./_skills/wrdn-authz;
				recursive = true;
			};
			".config/opencode/skills/wrdn-code-execution" = {
				source = ./_skills/wrdn-code-execution;
				recursive = true;
			};
			".config/opencode/skills/wrdn-data-exfil" = {
				source = ./_skills/wrdn-data-exfil;
				recursive = true;
			};
			".config/opencode/skills/wrdn-gha-workflows" = {
				source = ./_skills/wrdn-gha-workflows;
				recursive = true;
			};
			".config/opencode/skills/wrdn-pii" = {
				source = ./_skills/wrdn-pii;
				recursive = true;
			};
		};
		jsonFormat = pkgs.formats.json {};
		opencodeSettings =
			import ./_opencode/settings.nix {
				mcp = import ./_opencode/mcp.nix {};
			};
		tuiSettings = import ./_opencode/tui.nix {};
		supermemorySettings = import ./_opencode/supermemory.nix {};
		commands = import ./_opencode/commands.nix {};
		commandFiles =
			lib.mapAttrs' (
				name: text:
					lib.nameValuePair ".config/opencode/command/${name}.md" {
						inherit text;
					}
			)
			commands;
		configFiles = {
			".config/opencode/opencode.jsonc" = {
				source = jsonFormat.generate "opencode.jsonc" opencodeSettings;
				force = true;
			};
			".config/opencode/tui.json".source =
				jsonFormat.generate "opencode-tui.json" tuiSettings;
			".config/opencode/supermemory.jsonc".source =
				jsonFormat.generate "opencode-supermemory.jsonc" supermemorySettings;
		};
	in {
		home.packages =
			[
				inputs'.llm-agents.packages.opencode
				pkgs.bun
				pkgs.nodejs_24
			]
			++ lib.optionals pkgs.stdenv.isLinux [
				pkgs.xdg-utils
			];

		home.file =
			skills
			// commandFiles
			// configFiles;
	};
}
