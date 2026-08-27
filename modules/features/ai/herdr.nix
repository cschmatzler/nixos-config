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
    herdr-plugin-worktree-bootstrap = {
      url = "github:zerodice0/herdr-plugin-worktree-bootstrap/v0.4.0";
      flake = false;
    };
  };

  den.aspects.herdr.homeManager = {
    inputs',
    pkgs,
    ...
  }: let
    plugins = {
      gh-pr = inputs.herdr-plugin-gh-pr;
      worktree-bootstrap = inputs.herdr-plugin-worktree-bootstrap;
    };
    pluginRegistry = builtins.map (source: let
      manifest = builtins.fromTOML (builtins.readFile "${source}/herdr-plugin.toml");
    in {
      plugin_id = manifest.id;
      inherit (manifest) name version min_herdr_version;
      manifest_path = "${source}/herdr-plugin.toml";
      plugin_root = "${source}";
      enabled = true;
      source.kind = "local";
    }) (builtins.attrValues plugins);
  in {
    home = {
      packages = with pkgs; [
        bun
        gh
        git
        inputs'.herdr.packages.herdr
      ];

      file = {
        ".config/herdr/config.toml".source = (pkgs.formats.toml {}).generate "herdr-config.toml" (import ./_herdr/config.nix {
          theme = (import ../../_lib/theme.nix).rosePineDawn;
        });
        ".config/herdr/plugins.json".source = (pkgs.formats.json {}).generate "herdr-plugins.json" pluginRegistry;
      };
    };
  };
}
