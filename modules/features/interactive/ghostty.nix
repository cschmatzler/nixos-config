_: {
  den.aspects.ghostty.homeManager = {pkgs, ...}: {
    fonts.fontconfig = {
      enable = true;
      defaultFonts.monospace = ["TX-02"];
    };

    home.packages = pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [
      pkgs.ghostty.terminfo
    ];

    programs.ghostty = {
      enable = true;
      package = null;
      systemd.enable = false;
      enableBashIntegration = false;
      enableFishIntegration = false;
      enableZshIntegration = false;
      settings = {
        command = "${pkgs.fish}/bin/fish";
        theme = "Rose Pine Dawn";
        window-padding-x = 12;
        window-padding-y = 3;
        window-padding-balance = true;
        font-family = "TX-02";
        font-size = 14;
        cursor-style = "block";
        mouse-hide-while-typing = true;
        mouse-scroll-multiplier = 1.25;
        shell-integration = "none";
        shell-integration-features = "no-cursor";
        clipboard-read = "allow";
        clipboard-write = "allow";
      };
    };
  };
}
