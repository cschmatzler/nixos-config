{homeDirectory, ...}: let
  theme = (import ../_lib/theme.nix).catppuccinLatte;
in {
  model = "gpt-5.5";
  approval_policy = "on-request";
  sandbox_mode = "workspace-write";
  web_search = "cached";
  check_for_update_on_startup = false;

  tui = {
    theme = theme.codexThemeName;
    status_line = [
      "model-with-reasoning"
      "current-dir"
    ];
  };

  mcp_servers = import ./mcp.nix {};

  projects = {
    "${homeDirectory}/nixos-config".trust_level = "trusted";
    "${homeDirectory}/Projects".trust_level = "trusted";
  };
}
