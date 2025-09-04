{
  pkgs,
  hostname,
  user,
  ...
}: {
  imports = [
    ../../../modules/nixos
  ];

  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 42;
      };
      efi.canTouchEfiVariables = true;
    };
    initrd.availableKernelModules = [
      "xhci_pci"
      "ahci"
      "nvme"
      "usbhid"
      "usb_storage"
      "sd_mod"
    ];
    kernelPackages = pkgs.linuxPackages_latest;
  };

  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXROOT";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/NIXBOOT";
    fsType = "vfat";
  };

  networking = {
    hostName = hostname;
    useDHCP = false;
    interfaces.eno1.ipv4.addresses = [
      {
        address = "192.168.1.10";
        prefixLength = 24;
      }
    ];
    defaultGateway = "192.168.1.1";
    nameservers = ["1.1.1.1"];
  };

  sops.secrets = {
    tahani-syncthing-cert = {
      sopsFile = ../../../secrets/tahani-syncthing-cert;
      format = "binary";
      owner = user;
      path = "/home/${user}/.config/syncthing/cert.pem";
    };
    tahani-syncthing-key = {
      sopsFile = ../../../secrets/tahani-syncthing-key;
      format = "binary";
      owner = user;
      path = "/home/${user}/.config/syncthing/key.pem";
    };
  };

  services.syncthing.settings.folders = {
    "Projects/Personal" = {
      path = "/home/${user}/Projects/Personal";
      devices = ["tahani" "jason"];
    };
    "Projects/Work" = {
      path = "/home/${user}/Projects/Work";
      devices = ["tahani" "chidi"];
    };
  };

  home-manager.users.${user} = {
    programs.git.userEmail = "christoph@schmatzler.com";
  };
}
