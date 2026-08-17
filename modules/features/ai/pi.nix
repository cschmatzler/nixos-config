{den, ...}: {
  den.aspects.pi = {
    includes = [den.aspects.javascript];

    os.sops.secrets.supermemory-api-key = (import ../../_lib/secrets.nix {}).mkUserBinarySecret {
      name = "supermemory-api-key";
      sopsFile = ../../../secrets/supermemory-api-key;
    };

    homeManager = {
      config,
      inputs',
      lib,
      pkgs,
      ...
    }: let
      jsonFormat = pkgs.formats.json {};
      commandPayloads = import ./_shared/commands.nix;
      theme = (import ../../_lib/theme.nix).rosePine;
      settings = {
        theme = theme.slug;
        quietStartup = true;
        tuiMode = "fullscreen";
        hideThinkingBlock = true;
        showCacheMissNotices = true;
        defaultProvider = "openai-codex";
        defaultModel = "gpt-5.6-sol";
        defaultThinkingLevel = "medium";
        enableInstallTelemetry = false;
        packages =
          [
            "git:github.com/dmmulroy/pi-mcp@761c81dc5d4e0745f4ae77dcacb1be5517b18101"
            "npm:@ff-labs/pi-fff"
            "npm:mattpocock-skills-unofficial-plugin"
            "npm:pi-claude-auth"
            "npm:@juicesharp/rpiv-ask-user-question"
            "./packages/pi-herdr"
          ]
          ++ config.den.aspects.pi.packageDeclarations;
        prompts = ["./prompts"];
        skills = ["./skills"];
      };
    in {
      options.den.aspects.pi.packageDeclarations = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Additional package declarations inserted into Pi's package list";
      };

      config.home = {
        packages = [inputs'.llm-agents.packages.pi];

        file = {
          ".pi/tmp/.keep".text = "";
          ".pi/agent/settings.json".source = jsonFormat.generate "pi-settings.json" settings;
          ".pi/agent/themes/${theme.slug}.json".source = jsonFormat.generate "${theme.slug}.json" {
            "$schema" = "https://raw.githubusercontent.com/earendil-works/pi/main/packages/coding-agent/src/modes/interactive/theme/theme-schema.json";
            name = theme.slug;
            vars = theme.hex;
            inherit (theme.pi) colors export;
          };
          ".pi/agent/mcp.json".source = jsonFormat.generate "pi-mcp.json" {
            mcp = {
              toolMode = "direct";
              startup = "eager";
              servers = {
                opensrc = {
                  type = "local";
                  command = [
                    "npx"
                    "-y"
                    "opensrc-mcp"
                  ];
                  enabled = true;
                };
                executor = {
                  type = "remote";
                  url = "https://executor.manticore-hippocampus.ts.net/mcp/toolkits/general";
                  enabled = true;
                };
              };
            };
          };

          ".pi/agent/packages/pi-herdr" = {
            source = ./_pi/packages/pi-herdr;
            recursive = true;
          };

          ".pi/agent/prompts/rmslop.md".text = commandPayloads.rmslop;
          ".pi/agent/prompts/albanian-lesson.md".text = commandPayloads."albanian-lesson";
          ".pi/agent/prompts/inbox-triage.md".text = commandPayloads."inbox-triage";

          ".pi/agent/skills/coding-standards" = {
            source = ./_skills/coding-standards;
            recursive = true;
          };
          ".pi/agent/skills/effect" = {
            source = ./_skills/effect;
            recursive = true;
          };
          ".pi/agent/skills/life-os" = {
            source = ./_skills/life-os;
            recursive = true;
          };
          ".pi/agent/skills/wrdn-authz" = {
            source = ./_skills/wrdn-authz;
            recursive = true;
          };
          ".pi/agent/skills/wrdn-code-execution" = {
            source = ./_skills/wrdn-code-execution;
            recursive = true;
          };
          ".pi/agent/skills/wrdn-data-exfil" = {
            source = ./_skills/wrdn-data-exfil;
            recursive = true;
          };
          ".pi/agent/skills/wrdn-gha-workflows" = {
            source = ./_skills/wrdn-gha-workflows;
            recursive = true;
          };
          ".pi/agent/skills/wrdn-pii" = {
            source = ./_skills/wrdn-pii;
            recursive = true;
          };

          ".pi/agent/extensions/review.ts".source = ./_pi/extensions/review.ts;
          ".pi/agent/extensions/answer.ts".source = ./_pi/extensions/answer.ts;
          ".pi/agent/extensions/compact-footer.ts".source = ./_pi/extensions/compact-footer.ts;
          ".pi/agent/extensions/executor-resume-approval.ts".source = ./_pi/extensions/executor-resume-approval.ts;
          ".pi/agent/extensions/git-interceptor.ts".source = ./_pi/extensions/git-interceptor.ts;
          ".pi/agent/extensions/todos.ts".source = ./_pi/extensions/todos.ts;
          ".pi/agent/extensions/whimsical.ts".source = ./_pi/extensions/whimsical.ts;
        };
      };
    };
  };
}
