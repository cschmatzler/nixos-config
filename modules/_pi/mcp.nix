let
  local = import ../_lib/local.nix;
  executorUrl = "https://${local.tailscaleHost "executor"}/mcp";
in {
  mcp = {
    toolMode = "direct";
    startup = "eager";
    servers = {
      opensrc = {
        type = "local";
        command = [
          "npx"
          "-y"
          "opensrc-mcp"
        ];
        enabled = true;
      };
      executor = {
        type = "remote";
        url = "${executorUrl}?elicitation_mode=native";
        enabled = true;
      };
    };
  };
}
