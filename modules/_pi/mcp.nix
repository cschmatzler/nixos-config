let
  executorUrl = "https://executor.sh/leuchtturm/mcp";
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
