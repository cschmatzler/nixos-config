{
	constants,
	pkgs,
	user,
	...
}: {
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

	home-manager.useGlobalPkgs = true;
}
