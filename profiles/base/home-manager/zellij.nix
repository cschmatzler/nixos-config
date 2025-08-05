{ pkgs, ... }:
{
  programs.zellij = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      theme = "catppuccin-latte";
      default_layout = "compact";
      default_shell = "${pkgs.fish}/bin/fish";
      show_startup_tips = false;
      show_release_notes = false;
    };
  };
}
