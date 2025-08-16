{
  pkgs,
  nixvim,
  user,
  constants,
  sops-nix,
  ...
}: {
  imports = [
    ../core.nix
    ./firewall.nix
    ./ssh.nix
    ./adguard.nix
    ../tailscale.nix
    ../syncthing.nix
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
      _module.args = {inherit user constants;};
      imports = [
        nixvim.homeModules.nixvim
        ../home/default.nix
        ./home/default.nix
      ];
    };
  };
}
