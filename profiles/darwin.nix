{
	pkgs,
	inputs,
	user,
	constants,
	...
}: {
	home-manager.extraSpecialArgs = {inherit user constants inputs;};

	system = {
		primaryUser = user;
		stateVersion = constants.stateVersions.darwin;

		defaults = {
			NSGlobalDomain = {
				AppleInterfaceStyle = null;
				AppleShowAllExtensions = true;
				ApplePressAndHoldEnabled = false;
				KeyRepeat = 2;
				InitialKeyRepeat = 15;
				"com.apple.mouse.tapBehavior" = 1;
				"com.apple.sound.beep.volume" = 0.0;
				"com.apple.sound.beep.feedback" = 0;
				AppleShowScrollBars = "WhenScrolling";
				NSAutomaticCapitalizationEnabled = false;
				NSAutomaticDashSubstitutionEnabled = false;
				NSAutomaticPeriodSubstitutionEnabled = false;
				NSAutomaticQuoteSubstitutionEnabled = false;
				NSAutomaticSpellingCorrectionEnabled = false;
				NSDocumentSaveNewDocumentsToCloud = false;
				NSNavPanelExpandedStateForSaveMode = true;
				NSNavPanelExpandedStateForSaveMode2 = true;
				PMPrintingExpandedStateForPrint = true;
				PMPrintingExpandedStateForPrint2 = true;
			};

			dock = {
				autohide = true;
				show-recents = false;
				launchanim = true;
				orientation = "bottom";
				tilesize = 60;
				minimize-to-application = true;
				mru-spaces = false;
				expose-group-apps = true;
				wvous-bl-corner = 1;
				wvous-br-corner = 1;
				wvous-tl-corner = 1;
				wvous-tr-corner = 1;
			};

			finder = {
				_FXShowPosixPathInTitle = false;
				AppleShowAllFiles = true;
				FXEnableExtensionChangeWarning = false;
				FXPreferredViewStyle = "clmv";
				ShowPathbar = true;
				ShowStatusBar = true;
			};

			trackpad = {
				Clicking = true;
				TrackpadThreeFingerDrag = true;
			};

			screencapture = {
				location = "~/Screenshots";
				type = "png";
				disable-shadow = true;
			};

			screensaver = {
				askForPassword = true;
				askForPasswordDelay = 5;
			};

			loginwindow = {
				GuestEnabled = false;
				DisableConsoleAccess = true;
			};

			spaces.spans-displays = false;

			menuExtraClock = {
				Show24Hour = true;
				ShowDate = 1;
				ShowDayOfWeek = true;
				ShowSeconds = false;
			};

			CustomUserPreferences = {
				"com.apple.desktopservices" = {
					DSDontWriteNetworkStores = true;
					DSDontWriteUSBStores = true;
				};
				"com.apple.AdLib" = {
					allowApplePersonalizedAdvertising = false;
				};
				"com.apple.Spotlight" = {
					MenuItemHidden = true;
				};
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
