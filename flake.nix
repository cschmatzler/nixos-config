{
	description = "Configuration for my macOS laptops and NixOS server";

	inputs = {
		nixpkgs.url = "github:nixos/nixpkgs/master";
		flake-parts.url = "github:hercules-ci/flake-parts";
		sops-nix = {
			url = "github:Mic92/sops-nix";
			inputs.nixpkgs.follows = "nixpkgs";
		};
		home-manager = {
			url = "github:nix-community/home-manager";
			inputs.nixpkgs.follows = "nixpkgs";
		};
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
		nixvim.url = "github:nix-community/nixvim";
		zjstatus.url = "github:dj95/zjstatus";
	};

	outputs = inputs @ {flake-parts, ...}:
		flake-parts.lib.mkFlake {inherit inputs;} (
			let
				constants = import ./lib/constants.nix;
				user = constants.user;
				darwinHosts = ["chidi" "jason"];
				nixosHosts = ["tahani"];
				overlays = import ./overlays {inherit inputs;};
			in {
				systems = [
					"x86_64-linux"
					"aarch64-darwin"
				];

				flake.darwinConfigurations =
					inputs.nixpkgs.lib.genAttrs darwinHosts (
						hostname:
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
									{
										nixpkgs.overlays = overlays;

										nix-homebrew = {
											inherit user;
											enable = true;
											taps = {
												"homebrew/homebrew-core" = inputs.homebrew-core;
												"homebrew/homebrew-cask" = inputs.homebrew-cask;
											};
											mutableTaps = true;
										};
									}
									./hosts/${hostname}
								];
							}
					);

				flake.nixosConfigurations =
					inputs.nixpkgs.lib.genAttrs nixosHosts (
						hostname:
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
										nixpkgs.overlays = overlays;
									}
									./hosts/${hostname}
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
					devShells.default =
						pkgs.mkShell {
							nativeBuildInputs = with pkgs; [
								bashInteractive
								git
								age
								age-plugin-yubikey
							];
							shellHook = ''export EDITOR=nvim'';
						};

					apps =
						builtins.listToAttrs (
							map (n: {
									name = n;
									value = mkApp n;
								})
							appNames
						);
				};
				flake.overlays = overlays;
			}
		);
}
