{
  config,
  pkgs,
  lib,
  home-manager,
  nixvim,
  user,
  ...
}: let
  sharedFiles = import ../base/files.nix {inherit config pkgs;};
  additionalFiles = import ./files.nix {inherit config pkgs;};
in {
  imports = [
    ./packages.nix
    ./secrets.nix
    ./disk-config.nix
  ];

  users.users.${user} = {
    isNormalUser = true;
    home = "/home/${user}";
    extraGroups = [
      "wheel"
      "sudo"
      "network"
      "systemd-journal"
    ];
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
      _module.args = {inherit user;};
      imports = [
        nixvim.homeModules.nixvim
        ../base/home-manager
      ];
      home = {
        packages = pkgs.callPackage ./packages.nix {};
        file = lib.mkMerge [
          sharedFiles
          additionalFiles
        ];
        stateVersion = "23.11";
      };
    };
  };
}
