{
  pkgs,
  nixvim,
  user,
  constants,
  sops-nix,
  ...
}: {
  imports = [
    ../../core
    ../../networking/firewall.nix
    ../../networking/ssh.nix
    ./tailscale.nix
    ../../services/adguard.nix
    sops-nix.nixosModules.sops
  ];

  security.sudo.enable = true;

  system.stateVersion = constants.stateVersions.nixos;
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
      openssh.authorizedKeys.keys = constants.sshKeys;
    };

    root = {
      openssh.authorizedKeys.keys = constants.sshKeys;
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
        packages =
          pkgs.callPackage ../../packages {}
          ++ pkgs.callPackage ./packages.nix {};
        stateVersion = constants.stateVersions.homeManager;
      };
    };
  };
}
