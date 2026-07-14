{client}: let
  opensrcCommand = [
    "npx"
    "-y"
    "opensrc-mcp"
  ];
  executorUrl = "https://executor.sh/leuchtturm/mcp?elicitation_mode=browser";
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
  else if client == "pi"
  then {
    mcpServers = {
      opensrc = {
        command = builtins.head opensrcCommand;
        args = builtins.tail opensrcCommand;
        directTools = true;
        lifecycle = "eager";
      };
      executor = {
        url = executorUrl;
        directTools = true;
        lifecycle = "eager";
      };
    };
  }
  else throw "Unsupported MCP client: ${client}"
