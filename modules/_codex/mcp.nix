let
  local = import ../_lib/local.nix;
in {
  opensrc = {
    command = "npx";
    args = [
      "-y"
      "opensrc-mcp"
    ];
    enabled = true;
  };
  executor = {
    url = "https://${local.tailscaleHost "executor"}/mcp";
    enabled = true;
  };
  homeassistant = {
    url = "https://${local.tailscaleHost "ha"}/api/mcp";
    bearer_token_env_var = "HOME_ASSISTANT_TOKEN";
    enabled = true;
  };
}
