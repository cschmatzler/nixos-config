{
  den,
  inputs,
  lib,
  ...
}: {
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
      nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
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

  den = {
    hosts = let
      user = (import ./_lib/local.nix).user.name;
    in {
      aarch64-darwin.chidi.users.${user} = {};
      aarch64-darwin.janet.users.${user} = {};
      x86_64-linux.tahani.users.${user} = {};
    };

    default = {
      nixos.home-manager.useGlobalPkgs = true;
      darwin.home-manager.useGlobalPkgs = true;
      homeManager = {
        home.enableNixpkgsReleaseCheck = false;
        programs.home-manager.enable = true;
      };
      includes = [
        den.provides.define-user
        den.provides.inputs'
      ];
    };

    schema.user.classes = lib.mkDefault ["homeManager"];
  };
}
