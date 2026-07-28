{den, ...}: let
  mcp = import ./_lib/mcp.nix;
in {
  flake-file.inputs.llm-agents = {
    url = "github:numtide/llm-agents.nix";
    inputs.flake-parts.follows = "flake-parts";
  };

  den.aspects.ai-tools = {
    includes = [
      den.aspects.node-runtime
      den.aspects.opencode
    ];

    os = {pkgs, ...}: let
      settings = {
        check_for_update_on_startup = false;
        features.hooks = true;
        mcp_servers = mcp.codex;
      };
    in {
      environment.etc."codex/config.toml".source = (pkgs.formats.toml {}).generate "codex-config.toml" settings;
    };

    homeManager = {
      inputs',
      pkgs,
      ...
    }: let
      plannotator = inputs'.llm-agents.packages.plannotator;
      codex = pkgs.symlinkJoin {
        name = "codex";
        paths = [inputs'.llm-agents.packages.codex];
        nativeBuildInputs = [pkgs.makeWrapper];
        postBuild = ''
          wrapProgram $out/bin/codex \
            --run 'set -- --config "projects.\"$PWD\".trust_level=\"trusted\"" "$@"'
        '';
      };
      hooks = {
        hooks.Stop = [
          {
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
      plannotatorSkills = builtins.listToAttrs (map (name: {
          name = ".agents/skills/${name}";
          value = {
            source = "${plannotator.src}/apps/skills/core/${name}";
            recursive = true;
          };
        }) [
          "plannotator-review"
          "plannotator-annotate"
          "plannotator-last"
        ]);
    in {
      programs.claude-code = {
        enable = true;
        package = inputs'.llm-agents.packages.claude-code;
        mcpServers = mcp.servers;
      };

      home = {
        packages = [
          codex
          plannotator
        ];
        file =
          plannotatorSkills
          // {
            ".codex/hooks.json".source = (pkgs.formats.json {}).generate "codex-hooks.json" hooks;
          };
      };
    };
  };
}
