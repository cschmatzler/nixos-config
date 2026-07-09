{...}: {
  opensrc = {
    command = "npx";
    args = [
      "-y"
      "opensrc-mcp"
    ];
    enabled = true;
  };

  executor = {
    url = "https://executor.sh/leuchtturm/mcp?elicitation_mode=native";
    enabled = true;
  };
}
