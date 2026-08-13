{
  den,
  inputs,
  ...
}: {
  den.aspects.claude-code = {
    includes = [den.aspects.javascript];

    homeManager = {
      config,
      inputs',
      lib,
      pkgs,
      ...
    }: let
      aiTools = (import ./_shared/inventory.nix {
        inherit lib;
        local = import ../../_lib/local.nix;
      }).forAdapter "claude-code";
      mcpServers =
        lib.mapAttrs (
          name: endpoint:
            if endpoint.kind == "local"
            then {
              command = builtins.head endpoint.command;
              args = builtins.tail endpoint.command;
            }
            else if endpoint.kind == "remote"
            then {inherit (endpoint) url;}
            else throw "Unsupported Claude Code MCP kind for ${name}: ${endpoint.kind}"
        )
        aiTools.mcp;
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
        plugins.nono = inputs.nono-packs + "/claude";
        commands = lib.mapAttrs (_: command: command.text) aiTools.commands;
        skills = lib.mapAttrs (_: skill: skill.source) aiTools.skills;
        inherit mcpServers;
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
