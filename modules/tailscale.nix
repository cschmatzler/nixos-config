{lib, pkgs, ...}: {
  services.tailscale = {
    enable = true;
  } // lib.optionalAttrs pkgs.stdenv.isLinux {
    openFirewall = true;
    useRoutingFeatures = "server";
  };
}
