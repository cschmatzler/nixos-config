{
  programs.atuin = {
    enable = true;
    enableFishIntegration = true;
    daemon = {
      enable = true;
    };
    flags = [
      "--disable-up-arrow"
    ];
    settings = {
      style = "compact";
      inline_height = 0;
      show_help = false;
      show_tabs = false;
    };
  };
}
