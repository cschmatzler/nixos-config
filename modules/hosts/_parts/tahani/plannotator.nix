{
  lib,
  pkgs,
  ...
}: {
  systemd.services.plannotator-tailscale = (import ../../../_lib/tailscale-serve-exposure.nix {inherit lib;}) {
    inherit pkgs;
    workload = "Plannotator Pi plugin";
    identity = "svc:plannotator";
    port = 20000;
  };
}
