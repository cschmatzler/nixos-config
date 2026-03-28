{
	den,
	lib,
	...
}: {
	options.flake = {
		darwinConfigurations =
			lib.mkOption {
				type = lib.types.lazyAttrsOf lib.types.raw;
				default = {};
			};
		deploy =
			lib.mkOption {
				type = lib.types.lazyAttrsOf lib.types.raw;
				default = {};
			};
		flakeModules =
			lib.mkOption {
				type = lib.types.lazyAttrsOf lib.types.raw;
				default = {};
			};
	};

	config = {
		flake.flakeModules = {
			# Shared system foundations
			core = ./core.nix;
			darwin = ./darwin.nix;
			network = ./network.nix;
			nixos-system = ./nixos-system.nix;
			overlays = ./overlays.nix;
			secrets = ./secrets.nix;

			# Shared host features
			adguardhome = ./adguardhome.nix;
			cache = ./cache.nix;
			gitea = ./gitea.nix;
			notability = ./notability.nix;
			opencode = ./opencode.nix;
			paperless = ./paperless.nix;

			# User environment
			ai-tools = ./ai-tools.nix;
			atuin = ./atuin.nix;
			desktop = ./desktop.nix;
			dev-tools = ./dev-tools.nix;
			email = ./email.nix;
			neovim = ./neovim.nix;
			shell = ./shell.nix;
			ssh-client = ./ssh-client.nix;
			terminal = ./terminal.nix;
			zellij = ./zellij.nix;
			zk = ./zk.nix;
		};
		den.default.nixos.system.stateVersion = "25.11";
		den.default.darwin.system.stateVersion = 6;
		den.default.homeManager = {
			home.stateVersion = "25.11";
			programs.home-manager.enable = true;
		};
		den.default.nixos.home-manager.useGlobalPkgs = true;
		den.default.darwin.home-manager.useGlobalPkgs = true;

		den.default.includes = [
			den.provides.define-user
			den.provides.inputs'
		];

		den.schema.user.classes = lib.mkDefault ["homeManager"];
	};
}
