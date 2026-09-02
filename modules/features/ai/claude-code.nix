_: {
  flake-file.inputs.llm-agents = {
    url = "github:numtide/llm-agents.nix";
    inputs.flake-parts.follows = "flake-parts";
  };

  den.aspects.claude-code.homeManager = {inputs', ...}: {
    programs.claude-code = {
      enable = true;
      package = inputs'.llm-agents.packages.claude-code;
    };
  };
}
