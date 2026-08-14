{den, ...}: {
  den.aspects.pi = {
    includes = [den.aspects.javascript];

    os.sops.secrets.supermemory-api-key = (import ../../_lib/secrets.nix {}).mkUserBinarySecret {
      name = "supermemory-api-key";
      sopsFile = ../../../secrets/supermemory-api-key;
    };

    homeManager = {
      inputs',
      pkgs,
      ...
    }: let
      jsonFormat = pkgs.formats.json {};
      commandPayloads = import ./_shared/commands.nix;
      plannotatorConfig = {
        diffOptions = {
          defaultDiffType = "since-base";
          diffStyle = "split";
          diffIndicators = "bars";
          lineDiffType = "word-alt";
          fontFamily = "";
        };
        displayName = "Christoph Schmatzler";
        prompts.review.runtimes.pi.denied = ''
          The comments above are review directions written by the user. Treat them as intentional and correct by default, and address each one. Use the code to determine the right implementation. If a direction appears incorrect or harmful, raise the specific concern instead of following it blindly. Do not treat the comments as automated or unverified feedback, and do not require a verdict for each one.

          Review only the submitted comments. Do not independently review the rest of the diff or search for issues that were not submitted.
        '';
      };
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
          "git:github.com/dmmulroy/pi-mcp@761c81dc5d4e0745f4ae77dcacb1be5517b18101"
          "npm:@awesamarth/pi-supermemory"
          "./packages/pi-herdr"
          "npm:@plannotator/pi-extension"
          "npm:@tunnckocore/pi-gpt-fast-mode"
          "npm:pi-cache-optimizer"
          "npm:mattpocock-skills-unofficial-plugin"
          "npm:pi-claude-auth"
        ];
        prompts = ["./prompts"];
        skills = ["./skills"];
      };
    in {
      home = {
        packages = [inputs'.llm-agents.packages.pi];

        file = {
          ".plannotator/config.json".source = jsonFormat.generate "plannotator-config.json" plannotatorConfig;

          ".pi/tmp/.keep".text = "";
          ".pi/agent/settings.json".source = jsonFormat.generate "pi-settings.json" settings;
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
