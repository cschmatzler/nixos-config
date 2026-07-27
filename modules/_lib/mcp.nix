let
  local = import ./local.nix;
  servers = {
    opensrc = {
      transport = "stdio";
      command = "npx";
      args = [
        "-y"
        "opensrc-mcp"
      ];
    };
    executor = {
      transport = "http";
      url = "https://${local.tailscaleHost "executor"}/mcp";
    };
  };
  codexServer = _: server:
    builtins.removeAttrs server ["transport"]
    // {
      enabled = true;
    };
  claudeServer = _: server:
    builtins.removeAttrs server ["transport"]
    // {
      type = server.transport;
    };
  opencodeServer = _: server:
    if server.transport == "stdio"
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
  codex = builtins.mapAttrs codexServer servers;

  claude.mcpServers = builtins.mapAttrs claudeServer servers;

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
