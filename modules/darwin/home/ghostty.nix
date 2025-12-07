{pkgs, ...}: {
  programs.ghostty = {
    enable = true;
    package = pkgs.ghostty-bin;
    settings = {
      command = "${pkgs.fish}/bin/fish";
      theme = "Catppuccin Latte";
      window-padding-x = 12;
      window-padding-y = 3;
      window-padding-balance = true;
      font-family = "TX-02 SemiCondensed";
      font-size = 16.5;
      cursor-style = "block";
      mouse-hide-while-typing = true;
      mouse-scroll-multiplier = 1.25;
      shell-integration = "detect";
      shell-integration-features = "no-cursor";
      clipboard-read = "allow";
      clipboard-write = "allow";
    };
  };
}
