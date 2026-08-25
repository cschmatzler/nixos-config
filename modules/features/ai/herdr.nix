{inputs, ...}: {
  flake-file.inputs = {
    herdr = {
      url = "github:ogulcancelik/herdr";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    herdr-plugin-gh-pr = {
      url = "github:wyattjoh/herdr-plugin-gh-pr";
      flake = false;
    };
  };

  den.aspects.herdr.homeManager = {
    config,
    inputs',
    pkgs,
    ...
  }: let
    herdrPackage = inputs'.herdr.packages.herdr.overrideAttrs (old: {
      patches = (old.patches or []) ++ [./_herdr/subagent-visibility.patch];
    });
    pluginId = "gh-pr";
  in {
    home = {
      packages = with pkgs; [
        bun
        gh
        git
        herdrPackage
      ];

      file = {
        ".config/herdr/config.toml".source = (pkgs.formats.toml {}).generate "herdr-config.toml" (import ./_herdr/config.nix {
          theme = (import ../../_lib/theme.nix).rosePineDawn;
        });
        ".config/herdr/local-plugins/${pluginId}" = {
          source = inputs.herdr-plugin-gh-pr;
          recursive = true;
        };
      };
    };
  };
}
