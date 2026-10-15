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
    humanlayer-skills = {
      url = "github:humanlayer/skills";
      flake = false;
    };
  };

  den.aspects.agents = {
    includes = [den.aspects.dev-tools];

    homeManager = {
      config,
      inputs',
      lib,
      ...
    }: let
      skills = import ./_agents/skills.nix {inherit inputs lib;};
    in {
      programs.mcp = {
        enable = true;
        servers = {
          opensrc = {
            command = "npx";
            args = ["-y" "opensrc-mcp"];
          };
          executor.url = "https://v2.executor.sh/mcp";
          executor-selfhost.url = "https://executor.schmatzler.com/mcp";
          homeassistant.url = "https://${local.tailscaleHost "ha"}/api/mcp";
        };
      };

      programs.claude-code = {
        enable = true;
        package = inputs'.llm-agents.packages.claude-code;
        enableMcpIntegration = true;
        commandsDir = ./_agents/prompts;
        inherit skills;
        mcpServers.homeassistant = {
          type = "http";
          url = config.programs.mcp.servers.homeassistant.url;
          oauth = {
            clientId = "http://localhost:12345";
            callbackPort = 12345;
          };
        };
        settings.autoMemoryEnabled = false;
        settings.attribution = {
          commit = "";
          pr = "";
          sessionUrl = false;
        };
      };
    };
  };
}
