{
  den,
  inputs,
  ...
}: let
  local = import ../../_lib/local.nix;
in {
  flake-file.inputs = {
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.flake-parts.follows = "flake-parts";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dmmulroy-skills = {
      url = "github:dmmulroy/skills";
      flake = false;
    };
    humanlayer-skills = {
      url = "github:humanlayer/skills";
      flake = false;
    };
  };

  den.aspects.agents = {
    includes = [den.aspects.dev-tools];

    os = {config, ...}: {
      environment.etc."codex/config.toml".source =
        config.home-manager.users.${local.user.name}.home.file.".codex/config.toml".source;
    };

    homeManager = {
      inputs',
      lib,
      ...
    }: let
      skillDirs = path:
        lib.mapAttrs (name: _: path + "/${name}")
        (lib.filterAttrs (_: type: type == "directory") (builtins.readDir path));
      skills =
        skillDirs ./_agents/skills
        // {
          bro = inputs.dmmulroy-skills + "/bro";
          effect-service-design = inputs.dmmulroy-skills + "/effect-service-design";
          show-me = inputs.humanlayer-skills + "/plugins/show-me/skills/show-me";
        };
    in {
      programs.mcp = {
        enable = true;
        servers = {
          opensrc = {
            command = "npx";
            args = ["-y" "opensrc-mcp"];
          };
          executor.url = "https://executor.sh/mcp?search_tools=true";
        };
      };

      programs.claude-code = {
        enable = true;
        package = inputs'.llm-agents.packages.claude-code;
        enableMcpIntegration = true;
        commandsDir = ./_agents/prompts;
        inherit skills;
      };

      programs.codex = {
        enable = true;
        package = inputs'.llm-agents.packages.codex;
        enableMcpIntegration = true;
        inherit skills;
      };
      home.file.".codex/config.toml".enable = false;
      home.file.".codex/prompts".source = ./_agents/prompts;

      programs.opencode = {
        enable = true;
        package = inputs'.llm-agents.packages.opencode;
        enableMcpIntegration = true;
        commands = ./_agents/prompts;
        inherit skills;
      };
    };
  };
}
