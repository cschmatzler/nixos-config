{
  programs.opencode = {
    enable = true;
    settings = {
      theme = "system";
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
