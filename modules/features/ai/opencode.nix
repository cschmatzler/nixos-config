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
      homeassistantOAuth = config.programs.claude-code.mcpServers.homeassistant.oauth;
    in {
      programs.opencode = {
        enable = true;
        package = inputs'.llm-agents.packages.opencode2;
        skills = import ./_agents/skills.nix {inherit inputs lib;};
        settings = {
          update = "disable";
          plugins = ["@ex-machina/opencode-anthropic-auth@2.0.0-next.6"];

          # Home Manager's MCP integration still emits the v1 configuration shape.
          mcp.servers = lib.recursiveUpdate mcpServers {
            homeassistant.oauth = {
              client_id = homeassistantOAuth.clientId;
              callback_port = homeassistantOAuth.callbackPort;
              # Home Assistant requires the redirect host to match its client ID.
              redirect_uri = "${homeassistantOAuth.clientId}/callback";
            };
          };
        };
      };
    };
  };
}
