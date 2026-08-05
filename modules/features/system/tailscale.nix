_: {
  den.aspects.tailscale = {
    nixos.services.tailscale = {
      enable = true;
      extraSetFlags = ["--ssh"];
      openFirewall = true;
      useRoutingFeatures = "server";
    };

    darwin.homebrew.casks = ["tailscale-app"];
  };
}
