# Shared nix-darwin foundation and macOS policy.
{inputs, ...}:
with import ../../_lib/local.nix; {
  flake-file.inputs = {
    brew-api = {
      url = "github:BatteredBunny/brew-api";
      flake = false;
    };
    brew-nix = {
      url = "github:BatteredBunny/brew-nix";
      inputs = {
        brew-api.follows = "brew-api";
        nix-darwin.follows = "darwin";
        nixpkgs.follows = "nixpkgs";
      };
    };
  };

  den.aspects.darwin-system.darwin = {pkgs, ...}: {
    imports = [
      inputs.brew-nix.darwinModules.default
      inputs.home-manager.darwinModules.home-manager
    ];

    brew-nix.enable = true;

    system.primaryUser = user.name;

    security.pam.services.sudo_local.touchIdAuth = true;

    environment.systemPackages = with pkgs; [
      _1password-gui
      alcove
      brewCasks.cleanshot
      ghostty-bin
      brewCasks.helium-browser
      mas
      obsidian
      whatsapp-for-mac
    ];

    system.defaults = {
      NSGlobalDomain = {
        AppleInterfaceStyle = null;
        AppleKeyboardUIMode = 2;
        AppleShowAllExtensions = true;
        ApplePressAndHoldEnabled = false;
        KeyRepeat = 2;
        InitialKeyRepeat = 15;
        NSAutomaticInlinePredictionEnabled = false;
        NSStatusItemSelectionPadding = 4;
        NSStatusItemSpacing = 8;
        NSWindowShouldDragOnGesture = true;
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
        autohide-delay = 0.0;
        autohide-time-modifier = 0.15;
        show-recents = false;
        launchanim = true;
        orientation = "left";
        tilesize = 60;
        expose-animation-duration = 0.15;
        mineffect = "scale";
        minimize-to-application = true;
        mru-spaces = false;
        expose-group-apps = true;
        persistent-apps = [
          "/Applications/Nix Apps/Helium.app"
          "/Applications/Nix Apps/Ghostty.app"
          "/System/Applications/Music.app"
          "/System/Applications/Calendar.app"
          "/System/Applications/Mail.app"
        ];
        persistent-others = [
          {
            folder = {
              path = "${mkHome "aarch64-darwin"}/Downloads";
              arrangement = "name";
              displayas = "stack";
              showas = "grid";
            };
          }
        ];
        wvous-bl-corner = 1;
        wvous-br-corner = 1;
        wvous-tl-corner = 1;
        wvous-tr-corner = 1;
      };

      finder = {
        _FXShowPosixPathInTitle = false;
        AppleShowAllFiles = true;
        FXDefaultSearchScope = "SCcf";
        FXEnableExtensionChangeWarning = false;
        FXPreferredViewStyle = "clmv";
        FXRemoveOldTrashItems = true;
        NewWindowTarget = "Home";
        ShowPathbar = true;
        ShowStatusBar = true;
        _FXEnableColumnAutoSizing = true;
        _FXSortFoldersFirst = true;
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

      WindowManager = {
        EnableStandardClickToShowDesktop = false;
        EnableTiledWindowMargins = false;
        StandardHideWidgets = true;
      };

      controlcenter.BatteryShowPercentage = true;

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
          "NSStatusItem Visible Item-0" = false;
        };
        "com.apple.TextInputMenu" = {
          visible = false;
        };
      };
    };

    system.keyboard = {
      enableKeyMapping = true;
      remapCapsLockToEscape = true;
    };

    nix = {
      settings.trusted-users = [user.name];
      gc.interval = {
        Weekday = 0;
        Hour = 2;
        Minute = 0;
      };
      optimise = {
        automatic = true;
        interval = {
          Weekday = 0;
          Hour = 3;
          Minute = 0;
        };
      };
    };

    users.users.${user.name} = {
      name = user.name;
      home = mkHome "aarch64-darwin";
      isHidden = false;
      shell = pkgs.fish;
    };
  };
}
