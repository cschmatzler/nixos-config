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
        mcp_servers = import ./_codex/mcp.nix;
      };
    in {
      home = {
        packages = [
          inputs'.llm-agents.packages.claude-code
          codex
        ];
        file.".codex/config.toml".source = (pkgs.formats.toml {}).generate "codex-config.toml" settings;
      };
    };
  };
}
