{
  den,
  inputs,
  ...
}: let
  local = import ../../_lib/local.nix;
  proxyUrl = "https://${local.tailscaleHost "cliproxyapi"}";
  proxyKeyFile = "/run/secrets/cliproxyapi-client-api-key";
in {
  flake-file.inputs = {
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.flake-parts.follows = "flake-parts";
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
      sops.secrets.cliproxyapi-client-api-key = {
        sopsFile = ../../../secrets/cliproxyapi;
        key = "api-key";
        owner = local.user.name;
        path = proxyKeyFile;
      };
      environment.etc."codex/config.toml".source =
        config.home-manager.users.${local.user.name}.home.file.".codex/config.toml".source;
    };

    homeManager = {
      inputs',
      lib,
      pkgs,
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
        settings = {
          env.ANTHROPIC_BASE_URL = proxyUrl;
          apiKeyHelper = "${pkgs.coreutils}/bin/cat ${proxyKeyFile}";
        };
        enableMcpIntegration = true;
        commandsDir = ./_agents/prompts;
        inherit skills;
      };

      programs.codex = {
        enable = true;
        package = inputs'.llm-agents.packages.codex;
        enableMcpIntegration = true;
        settings = {
          model_provider = "cliproxyapi";
          model_providers.cliproxyapi = {
            name = "CLIProxyAPI";
            base_url = "${proxyUrl}/v1";
            wire_api = "responses";
            auth = {
              command = "${pkgs.coreutils}/bin/cat";
              args = [proxyKeyFile];
            };
          };
        };
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
