{den, ...}: {
  flake-file.inputs.llm-agents = {
    url = "github:numtide/llm-agents.nix";
    inputs.flake-parts.follows = "flake-parts";
  };

  den.aspects.ai-tools = {
    includes = [
      den.aspects.node-runtime
      den.aspects.pi
    ];

    homeManager = {
      inputs',
      pkgs,
      ...
    }: let
      mcp = import ./_lib/mcp.nix;
      resources = import ./_lib/agent-resources.nix;
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
      claudeSkills = builtins.listToAttrs (map (name: {
          inherit name;
          value = ./_skills + "/${name}";
        })
        resources.skillNames);
    in {
      programs.claude-code = {
        enable = true;
        package = inputs'.llm-agents.packages.claude-code;
        inherit (resources) commands;
        skills = claudeSkills;
        mcpServers = mcp.servers;
        settings.hooks = {
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

      home = {
        sessionVariables = {
          PLANNOTATOR_PORT = "20000";
          PLANNOTATOR_REMOTE = "1";
        };
        packages = [
          plannotator
        ];
      };
    };
  };
}
