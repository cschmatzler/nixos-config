{config, ...}: {
  networking.firewall = {
    enable = true;
    trustedInterfaces = ["eno1" "tailscale0"];
    allowedUDPPorts = [config.services.tailscale.port];
    allowedTCPPorts = [22];
    checkReversePath = "loose";
  };
}
