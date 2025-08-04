{
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set fish_greeting # Disable greeting
      set -gx LS_COLORS "$(vivid generate catppuccin-latte)"
    '';
  };
}
