{
  pkgs,
  ...
}:

{
  programs.ghostty = {
    enable = true;
    package = pkgs.ghostty-bin;
    settings = {
      command = "${pkgs.fish}/bin/fish";
      theme = "catppuccin-latte";
      window-padding-x = 8;
      window-padding-y = 2;
      window-padding-balance = true;
      font-family = "FiraCode Nerd Font";
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

      keybind = [
        "global:ctrl+shift+space=toggle_quick_terminal"
        "shift+enter=text:\\n"
        "ctrl+one=goto_tab:1"
        "ctrl+two=goto_tab:2"
        "ctrl+three=goto_tab:3"
        "ctrl+four=goto_tab:4"
        "ctrl+five=goto_tab:5"
        "ctrl+six=goto_tab:6"
        "ctrl+seven=goto_tab:7"
        "ctrl+eight=goto_tab:8"
        "ctrl+nine=goto_tab:9"
        "ctrl+left=previous_tab"
        "ctrl+right=next_tab"
        "ctrl+h=previous_tab"
        "ctrl+l=next_tab"
        "ctrl+shift+left=goto_split:left"
        "ctrl+shift+right=goto_split:right"
        "ctrl+shift+h=goto_split:left"
        "ctrl+shift+j=goto_split:down"
        "ctrl+shift+k=goto_split:up"
        "ctrl+shift+l=goto_split:right"
        "ctrl+shift+enter=new_split:right"
        "ctrl+t=new_tab"
        "ctrl+w=close_tab"
        "ctrl+shift+w=close_surface"
      ];
    };
  };
}
