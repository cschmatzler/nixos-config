_: let
  local = import ./_lib/local.nix;
  inherit (local) secretPath;
  secretLib = import ./_lib/secrets.nix {};
  supermemoryApiKeyPath = secretPath "supermemory-api-key";
in {
  den.aspects.pi = {
    os.sops.secrets.supermemory-api-key = secretLib.mkUserBinarySecret {
      name = "supermemory-api-key";
      sopsFile = ../secrets/supermemory-api-key;
    };

    homeManager = {
      inputs',
      lib,
      pkgs,
      ...
    }: let
      jsonFormat = pkgs.formats.json {};
      commands = import ./_pi/commands.nix;
      skillNames = [
        "coding-standards"
        "effect"
        "herdr"
        "rmslop"
        "wrdn-authz"
        "wrdn-code-execution"
        "wrdn-data-exfil"
        "wrdn-gha-workflows"
        "wrdn-pii"
      ];
      promptFiles =
        lib.mapAttrs' (
          name: text:
            lib.nameValuePair ".pi/agent/prompts/${name}.md" {
              inherit text;
            }
        )
        commands;
      skillFiles = builtins.listToAttrs (map (name: {
          name = ".pi/agent/skills/${name}";
          value = {
            source = ./_skills + "/${name}";
            recursive = true;
          };
        })
        skillNames);
      settings = {
        theme = "light";
        quietStartup = true;
        hideThinkingBlock = true;
        defaultProvider = "openai-codex";
        defaultModel = "gpt-5.6-sol";
        defaultThinkingLevel = "high";
        enableInstallTelemetry = false;
        packages = [
          "git:github.com/dmmulroy/pi-mcp"
          "npm:pi-cache-optimizer"
          "npm:pi-subagents"
          "npm:pi-claude-auth"
          "npm:@awesamarth/pi-supermemory"
        ];
        prompts = ["./prompts"];
        skills = ["./skills"];
      };
      configs = {
        ".pi/agent/settings.json".source = jsonFormat.generate "pi-settings.json" settings;
        ".pi/agent/mcp.json".source = jsonFormat.generate "pi-mcp.json" (import ./_lib/mcp.nix).pi;
        ".pi/agent/extensions/review.ts".source = ./_pi/extensions/review.ts;
        ".pi/agent/extensions/answer.ts".source = ./_pi/extensions/answer.ts;
        ".pi/agent/extensions/git-interceptor.ts".source = ./_pi/extensions/git-interceptor.ts;
        ".pi/agent/extensions/todos.ts".source = ./_pi/extensions/todos.ts;
        ".pi/agent/extensions/whimsical.ts".source = ./_pi/extensions/whimsical.ts;
      };
    in {
      programs.fish.shellInit = lib.mkAfter ''
        if test -f "${supermemoryApiKeyPath}"
          set -gx SUPERMEMORY_API_KEY (string trim -- (cat "${supermemoryApiKeyPath}"))
        end

        set -gx SUPERMEMORY_API_URL "https://api.supermemory.ai"
        set -gx PI_SKIP_VERSION_CHECK 1
      '';

      home = {
        packages = [
          inputs'.llm-agents.packages.pi
        ];
        file =
          promptFiles
          // skillFiles
          // configs;
      };
    };
  };
}
