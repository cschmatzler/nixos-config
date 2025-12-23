{
	constants,
	inputs,
	pkgs,
	user,
	...
}: {
	home-manager.extraSpecialArgs = {inherit user constants inputs;};

	system = {
		primaryUser = user;
		stateVersion = constants.stateVersions.darwin;

		defaults = {
			NSGlobalDomain = {
				# null equals "Light"
				AppleInterfaceStyle = null;
				AppleShowAllExtensions = true;
				ApplePressAndHoldEnabled = false;
				KeyRepeat = 2;
				InitialKeyRepeat = 15;
				"com.apple.mouse.tapBehavior" = 1;
				"com.apple.sound.beep.volume" = 0.0;
				"com.apple.sound.beep.feedback" = 0;
			};

			dock = {
				autohide = true;
				show-recents = false;
				launchanim = true;
				orientation = "bottom";
				tilesize = 60;
			};

			finder = {
				_FXShowPosixPathInTitle = false;
			};

			trackpad = {
				Clicking = true;
				TrackpadThreeFingerDrag = true;
			};
		};
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
		name = user;
		home = "/Users/${user}";
		isHidden = false;
		shell = pkgs.fish;
	};

	home-manager.useGlobalPkgs = true;
}
