{
  programs.opencode = {
    enable = true;
    settings = {
      theme = "catppuccin-mocha";
      instructions = [
        "CLAUDE.md"
        "AGENT.md"
        "AGENTS.md"
      ];
      formatter = {
        mix = {
          disabled = true;
        };
      };
    };
  };
}
