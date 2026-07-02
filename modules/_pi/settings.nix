{...}: let
  theme = (import ../_lib/theme.nix).catppuccinLatte;
in {
  theme = theme.piThemeName;
  quietStartup = true;
  defaultProvider = "openai-codex";
  defaultModel = "gpt-5.5";
  defaultThinkingLevel = "medium";
  hideThinkingBlock = true;
  transport = "websocket-cached";
  packages = [
    theme.piPackage
    "git:github.com/dmmulroy/pi-mcp"
    "npm:pi-better-openai"
    "npm:@juicesharp/rpiv-ask-user-question"
    "npm:@plannotator/pi-extension@0.21.1"
  ];
}
