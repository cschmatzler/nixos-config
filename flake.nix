# DO-NOT-EDIT. This file was auto-generated using github:vic/flake-file.
# Use `nix run .#write-flake` to regenerate it.
{
	outputs = inputs: inputs.flake-parts.lib.mkFlake {inherit inputs;} (inputs.import-tree ./modules);

	inputs = {
		darwin = {
			url = "github:LnL7/nix-darwin/master";
			inputs.nixpkgs.follows = "nixpkgs";
		};
		den.url = "github:vic/den";
		deploy-rs.url = "github:serokell/deploy-rs";
		disko = {
			url = "github:nix-community/disko";
			inputs.nixpkgs.follows = "nixpkgs";
		};
		flake-aspects.url = "github:vic/flake-aspects";
		flake-file.url = "github:vic/flake-file";
		flake-parts = {
			url = "github:hercules-ci/flake-parts";
			inputs.nixpkgs-lib.follows = "nixpkgs";
		};
		himalaya.url = "github:pimalaya/himalaya";
		home-manager = {
			url = "github:nix-community/home-manager";
			inputs.nixpkgs.follows = "nixpkgs";
		};
		homebrew-cask = {
			url = "github:homebrew/homebrew-cask";
			flake = false;
		};
		homebrew-core = {
			url = "github:homebrew/homebrew-core";
			flake = false;
		};
		import-tree.url = "github:vic/import-tree";
		jj-ryu = {
			url = "github:dmmulroy/jj-ryu";
			flake = false;
		};
		jj-starship.url = "github:dmmulroy/jj-starship";
		llm-agents.url = "github:numtide/llm-agents.nix";
		naersk = {
			url = "github:nix-community/naersk/master";
			inputs.nixpkgs.follows = "nixpkgs";
		};
		nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
		nixpkgs.url = "github:nixos/nixpkgs/master";
		nixpkgs-lib.follows = "nixpkgs";
		nixvim.url = "github:nix-community/nixvim";
		nono = {
			url = "github:always-further/nono";
			flake = false;
		};
		sops-nix = {
			url = "github:Mic92/sops-nix";
			inputs.nixpkgs.follows = "nixpkgs";
		};
		tuicr.url = "github:agavra/tuicr";
		zjstatus.url = "github:dj95/zjstatus";
	};
}
