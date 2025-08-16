{
  config,
  constants,
  nixvim,
  pkgs,
  user,
  sops-nix,
  ...
}: {
  imports = [
    ../core.nix
    ../tailscale.nix
    ../syncthing.nix
    ./dock
    ./homebrew.nix
    ./system.nix
    sops-nix.darwinModules.sops
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
      _module.args = {inherit user constants;};
      imports = [
        nixvim.homeModules.nixvim
        ../home/default.nix
        ../home/darwin/default.nix
      ];
      fonts.fontconfig.enable = true;
    };
  };

  local = {
    dock = {
      enable = true;
      username = user;
      entries = [
        {path = "/Applications/Safari.app/";}
        {path = "/${pkgs.ghostty-bin}/Applications/Ghostty.app/";}
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
