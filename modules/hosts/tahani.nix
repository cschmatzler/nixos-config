{den, ...}: let
  local = import ../_lib/local.nix;
in {
  den.aspects.tahani = {
    includes = [
      den.aspects.host-nixos-base
      den.aspects.home-assistant
      den.aspects.email
      den.aspects.syncthing
      den.aspects.t3code
      den.aspects.vscode-remote
    ];

    provides.to-users = {
      includes = [
        den.aspects.user-workstation
        den.aspects.user-personal
        den.aspects.email
        den.aspects.vscode-remote
      ];
      homeManager.home.stateVersion = "25.11";
    };

    nixos = {pkgs, ...}: {
      system.stateVersion = "25.11";
      networking.hostName = "tahani";

      boot = {
        loader = {
          systemd-boot = {
            enable = true;
            configurationLimit = 42;
          };
          efi.canTouchEfiVariables = true;
        };
        initrd.availableKernelModules = ["xhci_pci" "ahci" "nvme" "usbhid" "usb_storage" "sd_mod"];
        kernelPackages = pkgs.linuxPackages;
      };

      fileSystems."/" = {
        device = "/dev/disk/by-label/NIXROOT";
        fsType = "ext4";
      };
      fileSystems."/boot" = {
        device = "/dev/disk/by-label/NIXBOOT";
        fsType = "vfat";
      };
      swapDevices = [
        {
          device = "/swapfile";
          size = 16 * 1024;
        }
      ];

      networking = {
        useDHCP = false;
        interfaces.eno1.ipv4.addresses = [
          {
            address = "192.168.1.10";
            prefixLength = 24;
          }
        ];
        defaultGateway = "192.168.1.1";
        nameservers = ["1.1.1.1"];
        firewall = {
          enable = true;
          trustedInterfaces = ["eno1" "tailscale0" "docker0"];
          allowedTCPPorts = [22];
          checkReversePath = "loose";
        };
      };
      services.tailscale.extraSetFlags = ["--accept-routes=false"];

      environment.systemPackages = [pkgs._1password-cli];
      virtualisation.docker.enable = true;
      users.users.${local.user.name}.extraGroups = ["docker"];
    };
  };
}
