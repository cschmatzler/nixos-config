let
  local = import ./local.nix;
  servers = {
    opensrc = {
      command = "npx";
      args = [
        "-y"
        "opensrc-mcp"
      ];
    };
    executor = {
      url = "https://${local.tailscaleHost "executor"}/mcp";
    };
  };
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
in rec {
  inherit servers;

  codex = builtins.mapAttrs codexServer servers;

  opencode = builtins.mapAttrs opencodeServer servers;

  pi.mcp = {
    toolMode = "direct";
    startup = "eager";
    servers =
      opencode
      // {
        executor =
          opencode.executor
          // {
            url = "${servers.executor.url}?elicitation_mode=native";
          };
      };
  };
}
