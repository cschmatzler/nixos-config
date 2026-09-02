# systemd unit that exposes a local HTTP port as a Tailscale Service.
{
  pkgs,
  identity,
  port,
  after ? [],
}: {
  description = "Tailscale Serve for ${identity}";
  wantedBy = ["multi-user.target"];
  requires = ["tailscaled.service"] ++ after;
  after = ["tailscaled.service"] ++ after;
  serviceConfig = {
    Type = "oneshot";
    RemainAfterExit = true;
    ExecStart = "${pkgs.tailscale}/bin/tailscale serve --yes --service=${identity} --https=443 http://127.0.0.1:${toString port}";
    ExecStop = "${pkgs.tailscale}/bin/tailscale serve --yes --service=${identity} --https=443 off";
    Restart = "on-failure";
    RestartSec = "5s";
  };
}
