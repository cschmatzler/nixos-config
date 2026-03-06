{inputs, ...}: {
	imports = [
		(inputs.den.flakeModules.dendritic or {})
		(inputs.flake-file.flakeModules.dendritic or {})
	];

	# Use alejandra with tabs for flake.nix formatting (matches alejandra.toml)
	flake-file.formatter = pkgs:
		pkgs.writeShellApplication {
			name = "alejandra-tabs";
			runtimeInputs = [pkgs.alejandra];
			text = ''
				echo 'indentation = "Tabs"' > alejandra.toml
				alejandra "$@"
			'';
		};

	# Declare all framework and module inputs via flake-file
	flake-file.inputs = {
		den.url = "github:vic/den";
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
		deploy-rs.url = "github:serokell/deploy-rs";
		disko = {
			url = "github:nix-community/disko";
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
		llm-agents.url = "github:numtide/llm-agents.nix";
		# Overlay inputs
		himalaya.url = "github:pimalaya/himalaya";
		jj-ryu = {
			url = "github:dmmulroy/jj-ryu";
			flake = false;
		};
		jj-starship.url = "github:dmmulroy/jj-starship";
		zjstatus.url = "github:dj95/zjstatus";
		tuicr.url = "github:agavra/tuicr";
		naersk = {
			url = "github:nix-community/naersk/master";
			inputs.nixpkgs.follows = "nixpkgs";
		};
		nono = {
			url = "github:always-further/nono";
			flake = false;
		};
		# Secrets inputs
		sops-nix = {
			url = "github:Mic92/sops-nix";
			inputs.nixpkgs.follows = "nixpkgs";
		};
	};
}
