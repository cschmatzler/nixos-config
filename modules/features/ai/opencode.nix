{
  den,
  inputs,
  ...
}: {
  den.aspects.opencode = {
    includes = [den.aspects.agents];

    homeManager = {
      config,
      inputs',
      lib,
      ...
    }: let
      mcpServers =
        lib.mapAttrs (
          _: server:
            if server.url != null
            then {
              type = "remote";
              inherit (server) url;
            }
            else {
              type = "local";
              command = [server.command] ++ server.args;
            }
        )
        config.programs.mcp.servers;
    in {
      programs.opencode = {
        enable = true;
        package = inputs'.llm-agents.packages.opencode2;
        skills = import ./_agents/skills.nix {inherit inputs lib;};
        settings = {
          update = "disable";
          plugins = ["@ex-machina/opencode-anthropic-auth@2.0.0-next.6" "@rama_nigg/open-cursor"];

          # Home Manager's MCP integration still emits the v1 configuration shape.
          mcp.servers = lib.recursiveUpdate mcpServers {
            homeassistant.oauth = {
              client_id = "http://localhost:12345";
              callback_port = 12345;
              # Home Assistant requires the redirect host to match its client ID.
              redirect_uri = "http://localhost:12345/callback";
            };
          };
        };
      };
    };
  };
}
