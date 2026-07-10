{inputs, ...}: {
  imports = [
    (inputs.den.flakeModules.dendritic or {})
    (inputs.flake-file.flakeModules.dendritic or {})
  ];

  flake-file = {
    formatter = pkgs: pkgs.alejandra;
    inputs = {
      den.url = "github:denful/den";
      flake-file.url = "github:vic/flake-file";
      import-tree.url = "github:vic/import-tree";
      flake-aspects.url = "github:vic/flake-aspects";
      nixpkgs.url = "github:nixos/nixpkgs/master";
      flake-parts = {
        url = "github:hercules-ci/flake-parts";
        inputs.nixpkgs-lib.follows = "nixpkgs";
      };
      home-manager = {
        url = "github:nix-community/home-manager";
        inputs.nixpkgs.follows = "nixpkgs";
      };
      darwin = {
        url = "github:LnL7/nix-darwin/master";
        inputs.nixpkgs.follows = "nixpkgs";
      };
    };
  };
}
