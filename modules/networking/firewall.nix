{
  networking.firewall = {
    enable = true;
    trustedInterfaces = ["eno1" "tailscale0"];
  };
}
