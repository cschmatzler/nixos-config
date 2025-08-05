{
  nixpkgs,
  darwin,
  home-manager,
  nix-homebrew,
  homebrew-bundle,
  homebrew-core,
  homebrew-cask,
  disko,
  nixvim,
  self,
  ...
}@inputs:

let
  user = "cschmatzler";

  mkApp = scriptName: system: {
    type = "app";
    program = "${
      (nixpkgs.legacyPackages.${system}.writeScriptBin scriptName ''
        #!/usr/bin/env bash
        PATH=${nixpkgs.legacyPackages.${system}.git}/bin:$PATH
        echo "Running ${scriptName} for ${system}"
        exec ${self}/apps/${system}/${scriptName} "$@"
      '')
    }/bin/${scriptName}";
  };
in
{
  mkDarwinSystem =
    hostname:
    darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      specialArgs = inputs // {
        inherit user;
      };
      modules = [
        home-manager.darwinModules.home-manager
        nix-homebrew.darwinModules.nix-homebrew
        {
          nix-homebrew = {
            inherit user;
            enable = true;
            taps = {
              "homebrew/homebrew-core" = homebrew-core;
              "homebrew/homebrew-cask" = homebrew-cask;
              "homebrew/homebrew-bundle" = homebrew-bundle;
            };
            mutableTaps = false;
            autoMigrate = true;
          };
        }
        ../hosts/darwin/${hostname}
      ];
    };

  mkNixosSystem =
    hostname: system:
    nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = inputs // {
        inherit hostname user;
      };
      modules = [
        disko.nixosModules.disko
        home-manager.nixosModules.home-manager
        ../hosts/nixos
      ];
    };

  mkApps =
    system:
    let
      appNames = [
        "apply"
        "build"
        "build-switch"
        "copy-keys"
        "create-keys"
        "check-keys"
        "rollback"
      ];
    in
    nixpkgs.lib.genAttrs appNames (name: mkApp name system);

  systemConfigs = {
    darwinHosts = [
      "chidi"
      "jason"
    ];
    nixosHosts = [ "tahani" ];
  };
}
