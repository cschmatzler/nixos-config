{pkgs, ...}: {
  systemd.services.plannotator-tailscale = {
    description = "Expose Plannotator through Tailscale Serve";
    wantedBy = ["multi-user.target"];
    requires = ["tailscaled.service"];
    after = ["tailscaled.service"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.tailscale}/bin/tailscale serve --yes --service=svc:plannotator --https=443 http://127.0.0.1:20000";
      ExecStop = "${pkgs.tailscale}/bin/tailscale serve --yes --service=svc:plannotator --https=443 off";
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };
}
