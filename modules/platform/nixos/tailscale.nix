{
  services.tailscale = {
    enable = true;
    port = 41641;
    useRoutingFeatures = "server";
    openFirewall = true;
  };
}