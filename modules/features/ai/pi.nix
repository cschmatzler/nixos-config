{den, ...}: let
  local = import ../../_lib/local.nix;
  inherit (local) secretPath;
  secretLib = import ../../_lib/secrets.nix {};
  supermemoryApiKeyPath = secretPath "supermemory-api-key";
in {
  den.aspects.pi = {
    includes = [den.aspects.javascript];

    os.sops.secrets.supermemory-api-key = secretLib.mkUserBinarySecret {
      name = "supermemory-api-key";
      sopsFile = ../../../secrets/supermemory-api-key;
    };

    homeManager = {
      inputs',
      lib,
      pkgs,
      ...
    }: let
      jsonFormat = pkgs.formats.json {};
      resources = import ./_shared/agent-resources.nix;
      commands = removeAttrs resources.commands resources.plannotatorCommandNames;
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
        resources.skillNames);
      settings = {
        theme = "light";
        quietStartup = true;
        hideThinkingBlock = true;
        showCacheMissNotices = true;
        defaultProvider = "openai-codex";
        defaultModel = "gpt-5.6-sol";
        defaultThinkingLevel = "high";
        enableInstallTelemetry = false;
        packages = [
          "npm:pi-claude-auth"
          "git:github.com/dmmulroy/pi-mcp@761c81dc5d4e0745f4ae77dcacb1be5517b18101"
          "npm:@plannotator/pi-extension"
          "npm:@awesamarth/pi-supermemory"
          "npm:pi-subagents"
          "npm:pi-cache-optimizer"
          "npm:@tunnckocore/pi-gpt-fast-mode"
        ];
        prompts = ["./prompts"];
        skills = ["./skills"];
      };
      configs = {
        ".pi/agent/settings.json".source = jsonFormat.generate "pi-settings.json" settings;
        ".pi/agent/mcp.json".source = jsonFormat.generate "pi-mcp.json" (import ./_shared/mcp.nix).pi;
        ".pi/agent/extensions/review.ts".source = ./_pi/extensions/review.ts;
        ".pi/agent/extensions/answer.ts".source = ./_pi/extensions/answer.ts;
        ".pi/agent/extensions/compact-footer.ts".source = ./_pi/extensions/compact-footer.ts;
        ".pi/agent/extensions/executor-resume-approval.ts".source = ./_pi/extensions/executor-resume-approval.ts;
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
