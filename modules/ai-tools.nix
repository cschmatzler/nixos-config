{den, ...}: {
  flake-file.inputs.llm-agents = {
    url = "github:numtide/llm-agents.nix";
    inputs.flake-parts.follows = "flake-parts";
  };

  den.aspects.ai-tools = {
    includes = [
      den.aspects.node-runtime
      den.aspects.opencode
      den.aspects.pi
    ];

    homeManager = {inputs', ...}: {
      home.packages = [inputs'.llm-agents.packages.claude-code];
    };
  };
}
