{...}: {
  "$schema" = "https://opencode.ai/config.json";
  model = "opencode/gpt-5.5";
  autoupdate = false;
  mcp = import ./mcp.nix {};
  plugin = [
    [
      "@plannotator/opencode@0.22.0"
      {
        workflow = "plan-agent";
        planningAgents = ["plan"];
      }
    ]
  ];
  permission.skill."wrdn-*" = "allow";
}
