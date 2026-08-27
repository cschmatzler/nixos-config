{den, ...}: {
  den.aspects.claude-code.homeManager = {inputs', ...}: {
    programs.claude-code = {
      enable = true;
      package = inputs'.llm-agents.packages.claude-code;
    };
  };
}
