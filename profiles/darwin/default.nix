{
  config,
  pkgs,
  nixvim,
  user,
  ...
}: {
  imports = [
    ./secrets.nix
    ./system.nix
    ./homebrew.nix
    ./dock
  ];

  system = {
    primaryUser = user;
    stateVersion = 6;
  };

  nix.gc.interval = {
    Weekday = 0;
    Hour = 2;
    Minute = 0;
  };

  users.users.${user} = {
    name = "${user}";
    home = "/Users/${user}";
    isHidden = false;
    shell = pkgs.fish;
  };

  home-manager = {
    users.${user} = {
      pkgs,
      config,
      lib,
      ...
    }: {
      _module.args = {inherit user;};
      imports = [
        nixvim.homeModules.nixvim
        ../base/home-manager
        ./home-manager/ghostty.nix
      ];
      fonts.fontconfig.enable = true;
      home = {
        packages = pkgs.callPackage ../base/packages.nix {} ++ pkgs.callPackage ./packages.nix {};
        stateVersion = "25.11";
      };
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
