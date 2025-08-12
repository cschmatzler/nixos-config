{
  pkgs,
  nixvim,
  user,
  agenix,
  ...
}: let
  sshKeys = import ../../shared/ssh-keys.nix;
in {
  imports = [
    agenix.nixosModules.default
  ];

  system.stateVersion = "25.11";

  time.timeZone = "UTC";

  nix = {
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
    nixPath = ["nixos-config=/home/${user}/.local/share/src/nixos-config:/etc/nixos"];
  };

  virtualisation.docker = {
    enable = true;
    logDriver = "json-file";
  };

  services = {
    openssh = {
      enable = true;
      settings = {
        PermitRootLogin = "yes";
        PasswordAuthentication = false;
      };
    };
    tailscale.enable = true;
    adguardhome = {
      enable = true;
      settings = {
        http.address = "0.0.0.0:10000";
        dns = {
          upstream_dns = [
            "1.1.1.1"
            "1.0.0.1"
          ];
        };
        filtering = {
          protection_enabled = true;
          filtering_enabled = true;
          safe_search = {
            enabled = false;
          };
        };
      };
    };
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

  security.sudo = {
    enable = true;
    extraRules = [
      {
        commands = [
          {
            command = "${pkgs.systemd}/bin/reboot";
            options = ["NOPASSWD"];
          }
        ];
        groups = ["wheel"];
      }
    ];
  };

  environment.systemPackages = with pkgs; [
    agenix.packages."${pkgs.system}".default
    inetutils
  ];

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
        ./home-manager/zellij.nix
      ];
      home = {
        packages = pkgs.callPackage ../base/packages.nix {} ++ pkgs.callPackage ./packages.nix {};
        stateVersion = "25.11";
      };
    };
  };
}
