{den, ...}: {
  den.aspects.paper.darwin = {pkgs, ...}: {
    environment.systemPackages = [pkgs.brewCasks.paper-design];

    # Paper Desktop only exposes its MCP server on loopback. Make it reachable
    # from the agent host without exposing it to the LAN or public internet.
    #
    # The CLI must be invoked through its path inside the .app bundle: the
    # `bin/tailscale` symlink makes the binary fail to resolve its own bundle
    # identifier and it traps on startup.
    #
    # `tailscale serve` writes the proxy into tailscaled's prefs and exits, so
    # this runs once at login rather than being kept alive.
    launchd.user.agents.paper-mcp-tailscale.serviceConfig = {
      ProgramArguments = [
        "${pkgs.tailscale-gui}/Applications/Tailscale.app/Contents/MacOS/Tailscale"
        "serve"
        "--yes"
        "--service=svc:paper"
        "--https=443"
        "http://127.0.0.1:29979"
      ];
      RunAtLoad = true;
      ProcessType = "Background";
    };
  };
}
