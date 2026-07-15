{client}: let
  opensrcCommand = [
    "npx"
    "-y"
    "opensrc-mcp"
  ];
  executorUrl = "https://executor.sh/leuchtturm/mcp";
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
    mcp = {
      toolMode = "direct";
      startup = "eager";
      servers = {
        opensrc = {
          type = "local";
          command = opensrcCommand;
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
  else throw "Unsupported MCP client: ${client}"
