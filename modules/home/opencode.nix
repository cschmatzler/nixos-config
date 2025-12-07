{
  inputs,
  pkgs,
  ...
}: {
  programs.opencode = {
    enable = true;
    package = inputs.nix-ai-tools.packages.${pkgs.system}.opencode;
    settings = {
      theme = "catppuccin";
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
