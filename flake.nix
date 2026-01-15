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
		llm-agents.url = "github:numtide/llm-agents.nix";
		disko = {
			url = "github:nix-community/disko";
			inputs.nixpkgs.follows = "nixpkgs";
		};
		colmena = {
			url = "github:zhaofengli/colmena";
			inputs.nixpkgs.follows = "nixpkgs";
		};
		lumen = {
			url = "github:jnsahaj/lumen";
			inputs.nixpkgs.follows = "nixpkgs";
		};
		jj-ryu = {
			url = "github:dmmulroy/jj-ryu";
			flake = false;
		};
	};

	outputs = inputs @ {flake-parts, ...}:
		flake-parts.lib.mkFlake {inherit inputs;} (
			let
				inherit (inputs.nixpkgs) lib;
				constants = import ./lib/constants.nix;
				inherit (constants) user;

				darwinHosts = ["chidi" "jason"];
				nixosHosts = ["michael" "tahani"];

				overlays = import ./overlays {inherit inputs;};
				nixpkgsConfig = hostPlatform: {
					nixpkgs = {inherit hostPlatform overlays;};
				};
			in {
				systems = [
					"x86_64-linux"
					"aarch64-darwin"
				];

				flake.darwinConfigurations =
					lib.genAttrs darwinHosts (
						hostname:
							inputs.darwin.lib.darwinSystem {
								specialArgs = {inherit inputs user hostname constants;};
								modules = [
									inputs.home-manager.darwinModules.home-manager
									inputs.nix-homebrew.darwinModules.nix-homebrew
									(nixpkgsConfig "aarch64-darwin")
									{
										nix-homebrew = {
											inherit user;
											enable = true;
											mutableTaps = true;
											taps = {
												"homebrew/homebrew-core" = inputs.homebrew-core;
												"homebrew/homebrew-cask" = inputs.homebrew-cask;
											};
										};
									}
									./hosts/${hostname}
								];
							}
					);

				flake.nixosConfigurations =
					lib.genAttrs nixosHosts (
						hostname:
							lib.nixosSystem {
								specialArgs = {inherit inputs user hostname constants;};
								modules = [
									inputs.home-manager.nixosModules.home-manager
									(nixpkgsConfig "x86_64-linux")
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
					// lib.genAttrs nixosHosts (
						hostname: {
							deployment = {
								targetHost = hostname;
								targetUser = user;
							};
							imports = [
								inputs.home-manager.nixosModules.home-manager
								(nixpkgsConfig "x86_64-linux")
								{_module.args.hostname = hostname;}
								./hosts/${hostname}
							];
						}
					);

				flake.nixosModules = {
					pgbackrest = ./modules/pgbackrest.nix;
				};

				flake.lib = {inherit constants;};

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
					apps = pkgs.lib.genAttrs appNames mkApp;
				};
			}
		);
}
