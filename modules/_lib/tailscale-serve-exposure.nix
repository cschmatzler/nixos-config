{lib}: {
  pkgs,
  workload,
  identity,
  port,
  orderingUnits ? [],
}:
assert lib.assertMsg (workload != "") "Tailscale Serve workload must not be empty";
assert lib.assertMsg (lib.hasPrefix "svc:" identity) "Tailscale Serve identity must start with svc:";
assert lib.assertMsg (builtins.isInt port && port > 0 && port <= 65535) "Tailscale Serve port must be between 1 and 65535"; {
  description = "Expose ${workload} through Tailscale Serve";
  wantedBy = ["multi-user.target"];
  requires = lib.unique (orderingUnits ++ ["tailscaled.service"]);
  after = lib.unique (orderingUnits ++ ["tailscaled.service"]);
  serviceConfig = {
    Type = "oneshot";
    RemainAfterExit = true;
    ExecStart = "${pkgs.tailscale}/bin/tailscale serve --yes --service=${identity} --https=443 http://127.0.0.1:${toString port}";
    ExecStop = "${pkgs.tailscale}/bin/tailscale serve --yes --service=${identity} --https=443 off";
    Restart = "on-failure";
    RestartSec = "5s";
  };
}
