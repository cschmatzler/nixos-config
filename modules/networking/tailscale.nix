{ pkgs, lib, ... }:

{
  services.tailscale = {
    enable = true;
  } // lib.optionalAttrs pkgs.stdenv.isLinux {
    useRoutingFeatures = "server";
    openFirewall = true;
  };
}
