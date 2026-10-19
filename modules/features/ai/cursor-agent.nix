{den, ...}: {
  den.aspects.cursor-agent = {
    includes = [den.aspects.agents];

    homeManager = {inputs', ...}: {
      home.packages = [inputs'.llm-agents.packages.cursor-agent];
    };
  };
}
