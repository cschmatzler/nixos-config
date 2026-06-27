{...}: {
	den.aspects.codex.homeManager = {
		config,
		inputs',
		lib,
		pkgs,
		...
	}: let
		codexSupermemory = import ./_codex/supermemory-package.nix {inherit pkgs;};
		homeDirectory = config.home.homeDirectory;
		jsonFormat = pkgs.formats.json {};
		tomlFormat = pkgs.formats.toml {};
		codexSettings =
			import ./_codex/settings.nix {
				inherit homeDirectory;
				mcp = import ./_codex/mcp.nix {};
			};
		hooks =
			import ./_codex/hooks.nix {
				inherit homeDirectory;
			};
		supermemorySettings = import ./_codex/supermemory.nix {};
		wrdnSkills = {
			".codex/skills/wrdn-authz" = {
				source = ./_skills/wrdn-authz;
				recursive = true;
				force = true;
			};
			".codex/skills/wrdn-code-execution" = {
				source = ./_skills/wrdn-code-execution;
				recursive = true;
				force = true;
			};
			".codex/skills/wrdn-data-exfil" = {
				source = ./_skills/wrdn-data-exfil;
				recursive = true;
				force = true;
			};
			".codex/skills/wrdn-gha-workflows" = {
				source = ./_skills/wrdn-gha-workflows;
				recursive = true;
				force = true;
			};
			".codex/skills/wrdn-pii" = {
				source = ./_skills/wrdn-pii;
				recursive = true;
				force = true;
			};
		};
		supermemorySkills = {
			".codex/skills/supermemory-forget" = {
				source = "${codexSupermemory}/share/codex-supermemory/skills/supermemory-forget";
				recursive = true;
				force = true;
			};
			".codex/skills/supermemory-login" = {
				source = "${codexSupermemory}/share/codex-supermemory/skills/supermemory-login";
				recursive = true;
				force = true;
			};
			".codex/skills/supermemory-save" = {
				source = "${codexSupermemory}/share/codex-supermemory/skills/supermemory-save";
				recursive = true;
				force = true;
			};
			".codex/skills/supermemory-search" = {
				source = "${codexSupermemory}/share/codex-supermemory/skills/supermemory-search";
				recursive = true;
				force = true;
			};
		};
		supermemoryScripts = {
			".codex/supermemory/flush.js" = {
				source = "${codexSupermemory}/share/codex-supermemory/hooks/flush.js";
				force = true;
			};
			".codex/supermemory/forget-memory.js" = {
				source = "${codexSupermemory}/share/codex-supermemory/skills/forget-memory.js";
				force = true;
			};
			".codex/supermemory/login.js" = {
				source = "${codexSupermemory}/share/codex-supermemory/skills/login.js";
				force = true;
			};
			".codex/supermemory/recall.js" = {
				source = "${codexSupermemory}/share/codex-supermemory/hooks/recall.js";
				force = true;
			};
			".codex/supermemory/save-memory.js" = {
				source = "${codexSupermemory}/share/codex-supermemory/skills/save-memory.js";
				force = true;
			};
			".codex/supermemory/search-memory.js" = {
				source = "${codexSupermemory}/share/codex-supermemory/skills/search-memory.js";
				force = true;
			};
		};
		configFiles = {
			".codex/config.toml" = {
				source = tomlFormat.generate "codex-config.toml" codexSettings;
				force = true;
			};
			".codex/hooks.json" = {
				source = jsonFormat.generate "codex-hooks.json" hooks;
				force = true;
			};
			".codex/supermemory.json" = {
				source = jsonFormat.generate "codex-supermemory.json" supermemorySettings;
				force = true;
			};
		};
	in {
		home.packages =
			[
				inputs'.llm-agents.packages.codex
				codexSupermemory
				pkgs.nodejs_24
			]
			++ lib.optionals pkgs.stdenv.isLinux [
				pkgs.xdg-utils
			];

		home.file =
			wrdnSkills
			// supermemorySkills
			// supermemoryScripts
			// configFiles;
	};
}
