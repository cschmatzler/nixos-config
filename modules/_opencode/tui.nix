{...}: let
  theme = (import ../_lib/theme.nix).catppuccinLatte;
in {
  "$schema" = "https://opencode.ai/tui.json";
  theme = theme.opencodeThemeName;
}
