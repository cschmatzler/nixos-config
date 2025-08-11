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

  networking = {
    hostName = hostname;
    useDHCP = false;
    interfaces."%INTERFACE%".useDHCP = true;
  };

  system.stateVersion = "21.05";
}
