{...}: {
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
    url = "https://executor.sh/leuchtturm/mcp?elicitation_mode=native";
    enabled = true;
  };
}
