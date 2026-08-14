{den, ...}: {
  den.aspects.claude-code = {
    includes = [den.aspects.javascript];

    homeManager = {
      inputs',
      pkgs,
      ...
    }: let
      commandPayloads = import ./_shared/commands.nix;
      bunForPlannotator = pkgs.bun.overrideAttrs {
        version = "1.3.11";
        src = pkgs.fetchurl {
          url = "https://github.com/oven-sh/bun/releases/download/bun-v1.3.11/bun-darwin-aarch64.zip";
          hash = "sha256-b1o0Z+2crsR5W/eM1HZQfZ+HDH1XuGyUX8szgSZ3L/w=";
        };
      };
      plannotatorPackage = inputs'.llm-agents.packages.plannotator;
      plannotator =
        if pkgs.stdenv.isDarwin
        then
          plannotatorPackage.overrideAttrs (oldAttrs: {
            nativeBuildInputs = map (input:
              if (input.pname or null) == "bun"
              then bunForPlannotator
              else input)
            oldAttrs.nativeBuildInputs;
          })
        else plannotatorPackage;
    in {
      programs.claude-code = {
        enable = true;
        package = inputs'.llm-agents.packages.claude-code;
        commands = {
          rmslop = commandPayloads.rmslop;
          albanian-lesson = commandPayloads."albanian-lesson";
          inbox-triage = commandPayloads."inbox-triage";
          plannotator-annotate = commandPayloads."plannotator-annotate";
          plannotator-last = commandPayloads."plannotator-last";
          plannotator-review = commandPayloads."plannotator-review";
        };
        skills = {
          coding-standards = ./_skills/coding-standards;
          effect = ./_skills/effect;
          wrdn-authz = ./_skills/wrdn-authz;
          wrdn-code-execution = ./_skills/wrdn-code-execution;
          wrdn-data-exfil = ./_skills/wrdn-data-exfil;
          wrdn-gha-workflows = ./_skills/wrdn-gha-workflows;
          wrdn-pii = ./_skills/wrdn-pii;
        };
        mcpServers = {
          opensrc = {
            command = "npx";
            args = [
              "-y"
              "opensrc-mcp"
            ];
          };
          executor.url = "https://executor.manticore-hippocampus.ts.net/mcp/toolkits/general";
        };
        settings = {
          extraKnownMarketplaces.phase0-skills = {
            source = {
              source = "github";
              repo = "wefario/ai-agents-skills";
            };
            autoUpdate = true;
          };
          extraKnownMarketplaces.mattpocock = {
            source = {
              source = "github";
              repo = "mattpocock/skills";
            };
            autoUpdate = true;
          };
          enabledPlugins = {
            "phase0-skills@phase0-skills" = true;
            "mattpocock-skills@mattpocock" = true;
          };
          hooks = {
            PreToolUse = [
              {
                matcher = "EnterPlanMode";
                hooks = [
                  {
                    type = "command";
                    command = "${plannotator}/bin/plannotator improve-context";
                    timeout = 5;
                  }
                ];
              }
            ];
            PermissionRequest = [
              {
                matcher = "ExitPlanMode";
                hooks = [
                  {
                    type = "command";
                    command = "${plannotator}/bin/plannotator";
                    timeout = 345600;
                  }
                ];
              }
            ];
          };
        };
      };

      home = {
        file.".claude/tmp/.keep".text = "";
        sessionVariables = {
          DISABLE_AUTOUPDATER = "1";
          PLANNOTATOR_PORT = "20000";
          PLANNOTATOR_REMOTE = "1";
        };
        packages = [plannotator];
      };
    };
  };
}
