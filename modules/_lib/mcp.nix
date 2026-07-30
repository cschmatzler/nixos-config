let
  local = import ./local.nix;

  executorBaseUrl = "https://${local.tailscaleHost "executor"}/mcp";

  # The executor endpoint negotiates elicitation through a query parameter.
  # Clients that render MCP elicitation requests themselves ask for "native";
  # the rest use the server default of model-side resume.
  executorUrls = {
    default = executorBaseUrl;
    native = "${executorBaseUrl}?elicitation_mode=native";
  };

  mkServers = executorUrl: {
    opensrc = {
      command = "npx";
      args = [
        "-y"
        "opensrc-mcp"
      ];
    };
    executor = {
      url = executorUrl;
    };
  };

  servers = mkServers executorUrls.default;

  codexServer = _: server:
    server
    // {
      enabled = true;
    };

  opencodeServer = _: server:
    if server ? command
    then {
      type = "local";
      command = [server.command] ++ server.args;
      enabled = true;
    }
    else {
      type = "remote";
      inherit (server) url;
      enabled = true;
    };
in {
  inherit servers;

  codex = builtins.mapAttrs codexServer servers;

  opencode = builtins.mapAttrs opencodeServer servers;

  # pi-mcp (git:github.com/dmmulroy/pi-mcp) parses the OpenCode server schema
  # verbatim, so Pi reuses that adapter and only adds the loader options that
  # live alongside the servers in .pi/agent/mcp.json.
  pi.mcp = {
    toolMode = "direct";
    startup = "eager";
    servers = builtins.mapAttrs opencodeServer (mkServers executorUrls.native);
  };
}
