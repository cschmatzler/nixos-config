{
	description = "Configuration for my macOS laptops and NixOS server";

	inputs = {
		nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
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
		llm-agents.url = "github:numtide/llm-agents.nix";
		disko = {
			url = "github:nix-community/disko";
			inputs.nixpkgs.follows = "nixpkgs";
		};
		colmena = {
			url = "github:zhaofengli/colmena";
			inputs.nixpkgs.follows = "nixpkgs";
		};
	};

	outputs = inputs @ {flake-parts, ...}:
		flake-parts.lib.mkFlake {inherit inputs;} (
			let
				constants = import ./lib/constants.nix;
				user = constants.user;
				darwinHosts = ["chidi" "jason"];
				nixosHosts = ["michael" "mindy" "tahani"];
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
								specialArgs = {
									inherit inputs user hostname constants;
								};
								modules = [
									inputs.home-manager.darwinModules.home-manager
									inputs.nix-homebrew.darwinModules.nix-homebrew
									{
										nixpkgs.hostPlatform = "aarch64-darwin";
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
								specialArgs = {
									inherit inputs user hostname constants;
								};
								modules = [
									inputs.home-manager.nixosModules.home-manager
									{
										nixpkgs.hostPlatform = "x86_64-linux";
										nixpkgs.overlays = overlays;
									}
									./hosts/${hostname}
								];
							}
					);

				flake.colmena =
					{
						meta = {
							nixpkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
							specialArgs = {inherit inputs user constants;};
						};
					}
					// inputs.nixpkgs.lib.genAttrs nixosHosts (
						hostname: {
							deployment = {
								targetHost = hostname;
								targetUser = user;
							};
							imports = [
								inputs.home-manager.nixosModules.home-manager
								{
									nixpkgs.hostPlatform = "x86_64-linux";
									nixpkgs.overlays = overlays;
									_module.args.hostname = hostname;
								}
								./hosts/${hostname}
							];
						}
					);

				perSystem = {
					pkgs,
					system,
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
					apps =
						builtins.listToAttrs (
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
