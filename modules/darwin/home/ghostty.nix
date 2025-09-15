{pkgs, ...}: {
  programs.ghostty = {
    enable = true;
    package = pkgs.ghostty-bin;
    settings = {
      command = "${pkgs.fish}/bin/fish";
      theme = "Catppuccin Mocha";
      window-padding-x = 8;
      window-padding-y = 2;
      window-padding-balance = true;
      font-family = "Fira Code";
      font-size = 15.5;
      font-feature = [
        "-calt"
        "-dlig"
      ];
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
