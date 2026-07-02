{...}: {
  mcp = {
    startup = "eager";
    toolMode = "direct";
    servers = {
      opensrc = {
        type = "local";
        command = [
          "npx"
          "-y"
          "opensrc-mcp"
        ];
      };
      executor = {
        type = "remote";
        url = "https://executor.sh/leuchtturm/mcp?elicitation_mode=native";
      };
    };
  };
}
