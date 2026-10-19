{
  den,
  inputs,
  ...
}: let
  local = import ../../_lib/local.nix;
in {
  den.aspects.codex = {
    includes = [den.aspects.agents];

    os = {config, ...}: {
      environment.etc."codex/config.toml".source =
        config.home-manager.users.${local.user.name}.home.file.".codex/config.toml".source;
    };

    homeManager = {
      config,
      inputs',
      lib,
      ...
    }: {
      programs.codex = {
        enable = true;
        package = inputs'.llm-agents.packages.codex;
        enableMcpIntegration = true;
        skills = import ./_agents/skills.nix {inherit inputs lib;};
        settings.mcp_servers.homeassistant = {
          url = config.programs.mcp.servers.homeassistant.url;
          oauth = {
            client_id = "http://127.0.0.1:12345";
            callback_port = 12345;
          };
        };
      };
      home.file.".codex/config.toml".enable = false;
      home.file.".codex/prompts".source = ./_agents/prompts;
    };
  };
}
