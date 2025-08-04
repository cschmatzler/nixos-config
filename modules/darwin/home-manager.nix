{
  config,
  pkgs,
  lib,
  home-manager,
  ...
}:

let
  user = "cschmatzler";
  sharedFiles = import ../shared/files.nix { inherit config pkgs; };
  additionalFiles = import ./files.nix { inherit user config pkgs; };
in
{
  imports = [
    ./dock
  ];

  users.users.${user} = {
    name = "${user}";
    home = "/Users/${user}";
    isHidden = false;
    shell = pkgs.fish;
    ignoreShellProgramCheck = true;
  };

  homebrew = {
    enable = true;
    casks = pkgs.callPackage ./casks.nix { };

    masApps = { };
  };

  home-manager = {
    useGlobalPkgs = true;
    users.${user} =
      {
        pkgs,
        config,
        lib,
        ...
      }:
      {
        home = {
          enableNixpkgsReleaseCheck = false;
          packages = pkgs.callPackage ./packages.nix { };
          file = lib.mkMerge [
            sharedFiles
            additionalFiles
          ];
          stateVersion = "23.11";
        };
        programs = { } // import ../shared/home-manager.nix { inherit config pkgs lib; };
      };
  };

  local = {
    dock = {
      enable = true;
      username = user;
      entries = [
        { path = "/Applications/Safari.app/"; }
        { path = "/${pkgs.ghostty-bin}/Applications/Ghostty.app/"; }
        { path = "${pkgs.alacritty}/Applications/Alacritty.app/"; }
        { path = "/System/Applications/Notes.app/"; }
        { path = "/System/Applications/Music.app/"; }
        { path = "/System/Applications/System Settings.app/"; }
        {
          path = "${config.users.users.${user}.home}/Downloads";
          section = "others";
          options = "--sort name --view grid --display stack";
        }
      ];
    };
  };
}
