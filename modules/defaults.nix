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
	};

	config = {
		den.default.nixos.system.stateVersion = "25.11";
		den.default.darwin.system.stateVersion = 6;
		den.default.homeManager.home.stateVersion = "25.11";

		den.default.includes = [
			den.provides.define-user
			den.provides.inputs'
		];

		den.base.user.classes = lib.mkDefault ["homeManager"];
	};
}
