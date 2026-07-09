{...}: {
  "$schema" = "https://opencode.ai/config.json";
  model = "openai/gpt-5.5";
  autoupdate = false;
  mcp = import ./mcp.nix {};
  permission.skill."wrdn-*" = "allow";
}
