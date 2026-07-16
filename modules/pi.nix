_: let
  local = import ./_lib/local.nix;
  secretLib = import ./_lib/secrets.nix {};
  apiKeyPath = local.secretPath "opencode-api-key";
in {
  den.aspects.pi = {
    os.sops.secrets.opencode-api-key = secretLib.mkUserBinarySecret {
      name = "opencode-api-key";
      sopsFile = ../secrets/opencode-api-key;
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
      skillFiles =
        builtins.listToAttrs (map (name: {
            name = ".pi/agent/skills/${name}";
            value = {
              source = ./_skills + "/${name}";
              recursive = true;
            };
          })
          skillNames)
        // {
          ".pi/agent/skills/hunk-review/SKILL.md".source = "${inputs'.hunk.packages.hunk}/skills/hunk-review/SKILL.md";
        };
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
        ];
        prompts = ["./prompts"];
        skills = ["./skills"];
      };
      nonoProfile = import ./_pi/nono-profile.nix;
      configs = {
        ".pi/agent/settings.json".source = jsonFormat.generate "pi-settings.json" settings;
        ".pi/agent/mcp.json".source = jsonFormat.generate "pi-mcp.json" (import ./_pi/mcp.nix);
        ".pi/agent/extensions/review.ts".source = ./_pi/extensions/review.ts;
        ".pi/agent/extensions/answer.ts".source = ./_pi/extensions/answer.ts;
        ".pi/agent/extensions/git-interceptor.ts".source = ./_pi/extensions/git-interceptor.ts;
        ".pi/agent/extensions/todos.ts".source = ./_pi/extensions/todos.ts;
        ".pi/agent/extensions/whimsical.ts".source = ./_pi/extensions/whimsical.ts;
        ".config/nono/profiles/pi.json".source = jsonFormat.generate "nono-pi-profile.json" nonoProfile;
      };
    in {
      programs.fish.shellInit = lib.mkAfter ''
        set -gx PI_SKIP_VERSION_CHECK 1
        if test -f "${apiKeyPath}"
          set -gx OPENCODE_API_KEY (string trim -- (cat "${apiKeyPath}"))
        end
      '';

      home = {
        packages = [
          inputs'.llm-agents.packages.pi
        ];
        shellAliases.npi = "nono run --profile pi --allow-cwd -- pi";
        file =
          promptFiles
          // skillFiles
          // configs;
      };
    };
  };
}
