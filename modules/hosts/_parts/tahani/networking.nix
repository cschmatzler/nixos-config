_: {
  services.tailscale.extraSetFlags = ["--accept-routes=false"];

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
      allowedTCPPorts = [
        22
      ];
      checkReversePath = "loose";
    };
  };
}
