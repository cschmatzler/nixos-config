{den, ...}: {
  den.aspects.paper.darwin = {pkgs, ...}: {
    environment.systemPackages = [pkgs.brewCasks.paper-design];

    # Paper Desktop only exposes its MCP server on loopback. Make it reachable
    # from the agent host without exposing it to the LAN or public internet.
    launchd.user.agents.paper-mcp-tailscale.serviceConfig = {
      ProgramArguments = [
        "${pkgs.tailscale-gui}/bin/tailscale"
        "serve"
        "--yes"
        "--service=svc:paper"
        "--https=443"
        "http://127.0.0.1:29979"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      ProcessType = "Background";
      ThrottleInterval = 5;
    };
  };
}
