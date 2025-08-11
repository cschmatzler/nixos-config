{
  config,
  inputs,
  pkgs,
  agenix,
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
    useDHCP = false;
    interfaces."%INTERFACE%".useDHCP = true;
  };

  system.stateVersion = "21.05";
}
