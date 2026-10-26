{
  den,
  inputs,
  ...
}: {
  den.aspects.claude-code = {
    includes = [den.aspects.agents];

    homeManager = {
      config,
      inputs',
      ...
    }: {
      programs.claude-code = {
        enable = true;
        package = inputs'.llm-agents.packages.claude-code;
        enableMcpIntegration = true;
        commandsDir = ./_agents/prompts;
        skills = import ./_agents/skills.nix {inherit inputs;};
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
