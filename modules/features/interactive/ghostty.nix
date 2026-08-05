_: let
  theme = (import ../../_lib/theme.nix).rosePineDawn;
in {
  den.aspects.ghostty.homeManager = {pkgs, ...}: let
    settings = import ./_ghostty/settings.nix {inherit pkgs theme;};
    config =
      pkgs.lib.generators.toKeyValue {
        mkKeyValue = key: value: "${key} = ${
          if builtins.isBool value
          then pkgs.lib.boolToString value
          else toString value
        }";
      }
      settings;
  in {
    fonts.fontconfig = {
      enable = true;
      defaultFonts.monospace = ["MonoLisa"];
    };

    home.packages = pkgs.lib.optionals pkgs.stdenv.isLinux [
      pkgs.ghostty.terminfo
    ];

    xdg.configFile."ghostty/config".text = config;
  };
}
