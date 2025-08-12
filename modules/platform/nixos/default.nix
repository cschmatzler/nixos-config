{
  pkgs,
  nixvim,
  user,
  sops-nix,
  ...
}: let
  sshKeys = {
    keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILw2lQn2yEwprOzz50kxG4fKXHzq6askh+XSGLSnWidd"
    ];
  };
in {
  imports = [
    ../../core
    ../../networking/firewall.nix
    ../../networking/ssh.nix
    ./tailscale.nix
    ../../services/adguard.nix
    sops-nix.nixosModules.sops
  ];

  security.sudo.enable = true;

  system.stateVersion = "25.11";
  time.timeZone = "UTC";

  nix = {
    settings.trusted-users = ["${user}"];
    gc.dates = "weekly";
    nixPath = ["nixos-config=/home/${user}/.local/share/src/nixos-config:/etc/nixos"];
  };



  users.users = {
    ${user} = {
      isNormalUser = true;
      home = "/home/${user}";
      extraGroups = [
        "wheel"
        "sudo"
        "network"
        "systemd-journal"
        "docker"
      ];
      shell = pkgs.fish;
      openssh.authorizedKeys.keys = sshKeys.keys;
    };

    root = {
      openssh.authorizedKeys.keys = sshKeys.keys;
    };
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
        ../../home-manager/base
        ../../home-manager/nixos
      ];
      home = {
        packages = pkgs.callPackage ../../packages {} 
                ++ pkgs.callPackage ./packages.nix {};
        stateVersion = "25.11";
      };
    };
  };
}
