{sideshow}: let
  executorUrl = "https://executor.sh/leuchtturm/mcp";
in {
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
    url = "${executorUrl}?elicitation_mode=browser";
    enabled = true;
  };
  sideshow = {
    type = "local";
    command = [
      "${sideshow}/bin/sideshow"
      "mcp"
    ];
    enabled = true;
  };
}
