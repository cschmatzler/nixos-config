{
  description = "Configuration for my macOS laptops and NixOS server";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/master";
    flake-parts.url = "github:hercules-ci/flake-parts";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager.url = "github:nix-community/home-manager";
    darwin = {
      url = "github:LnL7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };
    homebrew-axe = {
      url = "github:cameroncooke/homebrew-axe";
      flake = false;
    };
    nixvim.url = "github:nix-community/nixvim";
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} (
      let
        constants = import ./lib/constants.nix;
        user = constants.user;
        darwinHosts = builtins.attrNames (builtins.readDir ./hosts/darwin);
        nixosHosts = builtins.attrNames (builtins.readDir ./hosts/nixos);
      in {
        systems = [
          "x86_64-linux"
          "aarch64-darwin"
        ];

        flake.darwinConfigurations = inputs.nixpkgs.lib.genAttrs darwinHosts (
          hostname: let
            syncthingOverlay = import ./overlays/syncthing-darwin.nix;
            syncthingModule = (syncthingOverlay null {}).darwinSyncthingModule;
            opencodeOverlay = import ./overlays/opencode.nix;
          in
            inputs.darwin.lib.darwinSystem {
              system = "aarch64-darwin";
              specialArgs =
                inputs
                // {
                  inherit user hostname constants;
                };
              modules = [
                inputs.home-manager.darwinModules.home-manager
                inputs.nix-homebrew.darwinModules.nix-homebrew
                syncthingModule

                {
                  nixpkgs.overlays = [syncthingOverlay opencodeOverlay];

                  nix-homebrew = {
                    inherit user;
                    enable = true;
                    taps = {
                      "homebrew/homebrew-core" = inputs.homebrew-core;
                      "homebrew/homebrew-cask" = inputs.homebrew-cask;
                      "cameroncooke/axe" = inputs.homebrew-axe;
                    };
                    mutableTaps = true;
                  };
                }
                ./hosts/darwin/${hostname}
              ];
            }
        );

        flake.nixosConfigurations = inputs.nixpkgs.lib.genAttrs nixosHosts (
          hostname: let
            opencodeOverlay = import ./overlays/opencode.nix;
          in
            inputs.nixpkgs.lib.nixosSystem {
              system = "x86_64-linux";
              specialArgs =
                inputs
                // {
                  inherit user hostname constants;
                };
              modules = [
                inputs.home-manager.nixosModules.home-manager
                {
                  nixpkgs.overlays = [opencodeOverlay];
                }
                ./hosts/nixos/${hostname}
              ];
            }
        );

        perSystem = {
          pkgs,
          system,
          inputs',
          ...
        }: let
          mkApp = name: {
            type = "app";
            program = "${(pkgs.writeShellScriptBin name ''
              PATH=${pkgs.git}/bin:$PATH
              echo "Running ${name} for ${system}"
              exec ${inputs.self}/apps/${system}/${name} "$@"
            '')}/bin/${name}";
          };

          appNames = [
            "apply"
            "build"
            "build-switch"
            "rollback"
          ];
        in {
          devShells.default = pkgs.mkShell {
            nativeBuildInputs = with pkgs; [
              bashInteractive
              git
              age
              age-plugin-yubikey
            ];
            shellHook = ''export EDITOR=nvim'';
          };

          apps = builtins.listToAttrs (
            map (n: {
              name = n;
              value = mkApp n;
            })
            appNames
          );
        };
      }
    );
}
