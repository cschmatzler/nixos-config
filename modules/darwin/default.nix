{
	config,
	constants,
	inputs,
	pkgs,
	user,
	...
}: {
	imports = [
		../core.nix
		../syncthing.nix
		../tailscale.nix
		./dock
		./homebrew.nix
		./syncthing.nix
		./system.nix
		inputs.sops-nix.darwinModules.sops
	];

	system = {
		primaryUser = user;
		stateVersion = constants.stateVersions.darwin;
	};

	nix = {
		settings.trusted-users = ["@admin" "${user}"];
		gc.interval = {
			Weekday = 0;
			Hour = 2;
			Minute = 0;
		};
	};

	users.users.${user} = {
		name = "${user}";
		home = "/Users/${user}";
		isHidden = false;
		shell = pkgs.fish;
	};

	home-manager = {
		useGlobalPkgs = true;
		users.${user} = {
			pkgs,
			config,
			lib,
			...
		}: {
			_module.args = {inherit user constants inputs;};
			imports = [
				inputs.nixvim.homeModules.nixvim
				../home/default.nix
				./home/default.nix
			];
			fonts.fontconfig.enable = true;
		};
	};

	local = {
		dock = {
			enable = true;
			username = user;
			entries = [
				{path = "/Applications/Helium.app/";}
				{path = "${config.users.users.${user}.home}/Applications/Home Manager Apps/Ghostty.app/";}
				{path = "/System/Applications/Calendar.app/";}
				{path = "/System/Applications/Mail.app/";}
				{path = "/System/Applications/Notes.app/";}
				{path = "/System/Applications/Music.app/";}
				{path = "/System/Applications/System Settings.app/";}
				{
					path = "${config.users.users.${user}.home}/Downloads";
					section = "others";
					options = "--sort name --view grid --display stack";
				}
			];
		};
	};
}
