let
  local = import ../_lib/local.nix;
  executorUrl = "https://${local.tailscaleHost "executor"}/mcp";
in {
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
    url = "${executorUrl}";
    enabled = true;
  };
  homeassistant = {
    type = "remote";
    url = "https://${local.tailscaleHost "ha"}/api/mcp";
    headers.Authorization = "Bearer {env:HOME_ASSISTANT_TOKEN}";
    oauth = false;
    enabled = true;
  };
}
