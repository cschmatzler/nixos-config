_: {
  "$schema" = "https://opencode.ai/config.json";
  model = "openai/gpt-5.5";
  autoupdate = false;
  plugin = [
    [
      "@plannotator/opencode@latest"
      {
        runtime = "cli";
        workflow = "plan-agent";
        planningAgents = ["plan"];
      }
    ]
  ];
  mcp = import ../_ai/mcp.nix {client = "opencode";};
  permission.skill."wrdn-*" = "allow";
}
