{
  description = "Configuration for my macOS laptops and NixOS server";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    agenix.url = "github:ryantm/agenix";
    home-manager.url = "github:nix-community/home-manager";
    darwin = {
      url = "github:LnL7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew = {
      url = "github:zhaofengli-wip/nix-homebrew";
    };
    homebrew-bundle = {
      url = "github:homebrew/homebrew-bundle";
      flake = false;
    };
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    secrets = {
      url = "git+ssh://git@github.com/cschmatzler/nixos-config-secrets.git";
      flake = false;
    };
  };
  outputs =
    {
      self,
      darwin,
      nix-homebrew,
      homebrew-bundle,
      homebrew-core,
      homebrew-cask,
      home-manager,
      nixpkgs,
      disko,
      agenix,
      nixvim,
      secrets,
    }@inputs:
    let
      systemLib = import ./lib/systems.nix inputs;
      inherit (systemLib)
        systemConfigs
        mkDarwinSystem
        mkNixosSystem
        mkApps
        ;
      inherit (systemConfigs) darwinHosts nixosHosts;

      allSystems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs allSystems f;
      devShell =
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default =
            with pkgs;
            mkShell {
              nativeBuildInputs = with pkgs; [
                bashInteractive
                git
                age
                age-plugin-yubikey
              ];
              shellHook = with pkgs; ''
                export EDITOR=nvim
              '';
            };
        };
    in
    {
      devShells = forAllSystems devShell;
      apps = forAllSystems mkApps;
      darwinConfigurations = nixpkgs.lib.genAttrs darwinHosts mkDarwinSystem;
      nixosConfigurations = nixpkgs.lib.genAttrs nixosHosts (
        hostname: mkNixosSystem hostname "x86_64-linux"
      );
    };
}
