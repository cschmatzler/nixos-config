# DO-NOT-EDIT. This file was auto-generated using github:vic/flake-file.
# Use `nix run .#write-flake` to regenerate it.
{
	outputs = inputs: inputs.flake-parts.lib.mkFlake {inherit inputs;} (inputs.import-tree ./modules);

	inputs = {
		darwin = {
			inputs.nixpkgs.follows = "nixpkgs";
			url = "github:LnL7/nix-darwin/master";
		};
		den.url = "github:vic/den";
		deploy-rs.url = "github:serokell/deploy-rs";
		disko = {
			inputs.nixpkgs.follows = "nixpkgs";
			url = "github:nix-community/disko";
		};
		flake-aspects.url = "github:vic/flake-aspects";
		flake-file.url = "github:vic/flake-file";
		flake-parts = {
			inputs.nixpkgs-lib.follows = "nixpkgs";
			url = "github:hercules-ci/flake-parts";
		};
		himalaya.url = "github:pimalaya/himalaya";
		home-manager = {
			inputs.nixpkgs.follows = "nixpkgs";
			url = "github:nix-community/home-manager";
		};
		homebrew-cask = {
			flake = false;
			url = "github:homebrew/homebrew-cask";
		};
		homebrew-core = {
			flake = false;
			url = "github:homebrew/homebrew-core";
		};
		import-tree.url = "github:vic/import-tree";
		jj-ryu = {
			flake = false;
			url = "github:dmmulroy/jj-ryu";
		};
		jj-starship.url = "github:dmmulroy/jj-starship";
		llm-agents.url = "github:numtide/llm-agents.nix";
		naersk = {
			inputs.nixpkgs.follows = "nixpkgs";
			url = "github:nix-community/naersk/master";
		};
		nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
		nixpkgs.url = "github:nixos/nixpkgs/master";
		nixpkgs-lib.follows = "nixpkgs";
		nixvim.url = "github:nix-community/nixvim";
		nono = {
			flake = false;
			url = "github:always-further/nono";
		};
		sops-nix = {
			inputs.nixpkgs.follows = "nixpkgs";
			url = "github:Mic92/sops-nix";
		};
		tuicr.url = "github:agavra/tuicr";
		zjstatus.url = "github:dj95/zjstatus";
	};
}
