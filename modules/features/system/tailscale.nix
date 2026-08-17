_: {
  den.aspects.tailscale = {
    nixos.services.tailscale = {
      enable = true;
      extraSetFlags = ["--ssh"];
      openFirewall = true;
      useRoutingFeatures = "server";
    };

    darwin = {pkgs, ...}: {
      environment.systemPackages = [pkgs.tailscale-gui];
    };
  };
}
