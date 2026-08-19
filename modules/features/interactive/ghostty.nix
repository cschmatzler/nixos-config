_: {
  den.aspects.ghostty.homeManager = {pkgs, ...}: {
    fonts.fontconfig = {
      enable = true;
      defaultFonts.monospace = ["TX-02"];
    };

    home.packages = pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [
      pkgs.ghostty.terminfo
    ];

    xdg.configFile."ghostty/config".text =
      pkgs.lib.generators.toKeyValue {
        mkKeyValue = key: value: "${key} = ${
          if builtins.isBool value
          then pkgs.lib.boolToString value
          else toString value
        }";
      } (import ./_ghostty/settings.nix {
        inherit pkgs;
        theme = (import ../../_lib/theme.nix).rosePine;
      });
  };
}
