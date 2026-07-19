_: let
  renderHerdrConfig = import ./_herdr/render-config.nix;
  theme = (import ./_lib/theme.nix).rosePineDawn;
in {
  flake-file.inputs.herdr = {
    url = "github:ogulcancelik/herdr";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  den.aspects.herdr.homeManager = {inputs', ...}: {
    home.packages = [
      inputs'.herdr.packages.herdr
    ];

    home.file.".config/herdr/config.toml".text = renderHerdrConfig {inherit theme;};
  };
}
