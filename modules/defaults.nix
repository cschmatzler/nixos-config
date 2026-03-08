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
			ai-tools = ./ai-tools.nix;
			atuin = ./atuin.nix;
			core = ./core.nix;
			desktop = ./desktop.nix;
			dev-tools = ./dev-tools.nix;
			email = ./email.nix;
			finance = ./finance.nix;
			neovim = ./neovim.nix;
			network = ./network.nix;
			nixos-system = ./nixos-system.nix;
			shell = ./shell.nix;
			ssh-client = ./ssh-client.nix;
			terminal = ./terminal.nix;
			user = ./user.nix;
			zellij = ./zellij.nix;
			zk = ./zk.nix;
		};
		den.default.nixos.system.stateVersion = "25.11";
		den.default.darwin.system.stateVersion = 6;
		den.default.homeManager.home.stateVersion = "25.11";

		den.default.includes = [
			den.provides.define-user
			den.provides.inputs'
		];

		den.schema.user.classes = lib.mkDefault ["homeManager"];
	};
}
