{
  lib,
  pkgs,
  ...
}: let
  mkTailscaleServeExposure = import ../../../_lib/tailscale-serve-exposure.nix {inherit lib;};
in {
  systemd.services.plannotator-tailscale = mkTailscaleServeExposure {
    inherit pkgs;
    workload = "Plannotator Pi plugin";
    identity = "svc:plannotator";
    port = 20000;
  };
}
