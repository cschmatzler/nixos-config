{client}: let
  opensrcCommand = [
    "npx"
    "-y"
    "opensrc-mcp"
  ];
  executorUrl = "https://executor.sh/leuchtturm/mcp?elicitation_mode=native";
in
  if client == "codex"
  then {
    opensrc = {
      command = builtins.head opensrcCommand;
      args = builtins.tail opensrcCommand;
      enabled = true;
    };
    executor = {
      url = executorUrl;
      enabled = true;
    };
  }
  else if client == "opencode"
  then {
    opensrc = {
      type = "local";
      command = opensrcCommand;
      enabled = true;
    };
    executor = {
      type = "remote";
      url = executorUrl;
      enabled = true;
    };
  }
  else throw "Unsupported MCP client: ${client}"
