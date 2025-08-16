{
  lib,
  pkgs,
  ...
}: {
  programs.zellij = {
    enable = true;
    enableFishIntegration = lib.mkDefault false;
    settings = {
      theme = "catppuccin-latte";
      default_layout = "compact";
      default_shell = "${pkgs.fish}/bin/fish";
      pane_frames = false;
      show_startup_tips = false;
      show_release_notes = false;
    };
  };
}
