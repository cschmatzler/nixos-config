{den, ...}: let
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
    tstack = {
      url = "github:t3dotgg/tstack";
      flake = false;
    };
  };

  den.aspects.agents = {
    includes = [den.aspects.dev-tools];

    homeManager = {
      programs.mcp = {
        enable = true;
        servers = {
          opensrc = {
            command = "npx";
            args = ["-y" "opensrc-mcp"];
          };
          executor.url = "https://executor.leuchtturm.dev/mcp";
          homeassistant.url = "https://${local.tailscaleHost "ha"}/api/mcp";
        };
      };
    };
  };
}
