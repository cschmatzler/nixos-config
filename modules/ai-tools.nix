{den, ...}: {
  flake-file.inputs.llm-agents = {
    url = "github:numtide/llm-agents.nix";
    inputs.flake-parts.follows = "flake-parts";
  };

  den.aspects.ai-tools = {
    includes = [
      den.aspects.node-runtime
      den.aspects.opencode
      den.aspects.pi
    ];

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
      settings = {
        check_for_update_on_startup = false;
        features.hooks = true;
        mcp_servers = import ./_codex/mcp.nix;
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
      home = {
        packages = [
          inputs'.llm-agents.packages.claude-code
          codex
          plannotator
        ];
        file =
          plannotatorSkills
          // {
            ".codex/config.toml".source = (pkgs.formats.toml {}).generate "codex-config.toml" settings;
            ".codex/hooks.json".source = (pkgs.formats.json {}).generate "codex-hooks.json" hooks;
          };
      };
    };
  };
}
