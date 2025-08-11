{
  pkgs,
  hostname,
  user,
  ...
}: {
  imports = [
    ../../../profiles/base
    ../../../profiles/nixos
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
    useDHCP = true;
  };

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_17;
    extensions = [pkgs.postgresql17Packages.timescaledb];
    enableTCPIP = true;
    ensureDatabases = ["postgres"];
    ensureUsers = [
      {
        name = "postgres";
        ensureDBOwnership = true;
      }
      {
        name = "cschmatzler";
        ensureClauses = {
          superuser = true;
          createdb = true;
        };
      }
    ];
    authentication = pkgs.lib.mkOverride 10 ''
      local all all trust
      host  all all 127.0.0.1/32 trust
      host  all all ::1/128 trust
    '';
    settings = {
      shared_preload_libraries = ["timescaledb"];
    };
  };

  services.clickhouse = {
    enable = true;
  };

  home-manager.users.${user} = {
    programs.git.userEmail = "christoph@schmatzler.com";
  };
}
