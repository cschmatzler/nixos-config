let
  local = import ./local.nix;

  executorUrl = "https://${local.tailscaleHost "executor"}/mcp/toolkits/general";

  servers = {
    opensrc = {
      command = "npx";
      args = [
        "-y"
        "opensrc-mcp"
      ];
    };
    executor.url = executorUrl;
  };

  codex = builtins.mapAttrs (_: server: server // {enabled = true;}) servers;

  opencode =
    builtins.mapAttrs (
      _: server:
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
        }
    )
    servers;
in {
  inherit servers codex opencode;

  # pi-mcp parses the OpenCode server schema verbatim.
  pi.mcp = {
    toolMode = "direct";
    startup = "eager";
    servers = opencode;
  };
}
