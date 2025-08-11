{pkgs, ...}: {
  programs.zellij = {
    enable = true;
    enableFishIntegration = false;
    settings = {
      theme = "catppuccin-latte";
      default_layout = "compact";
      default_shell = "${pkgs.fish}/bin/fish";
      no_pane_frames = true;
      show_startup_tips = false;
      show_release_notes = false;
    };
  };
}
