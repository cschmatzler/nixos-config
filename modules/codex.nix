_: {
  den.aspects.codex.homeManager = {
    config,
    lib,
    pkgs,
    inputs',
    ...
  }: let
    jsonFormat = pkgs.formats.json {};
    tomlFormat = pkgs.formats.toml {};
    mkNonoProfile = import ./_ai/nono-profile.nix;
    commands = import ./_ai/commands.nix {frontmatter = false;};
    commandFiles =
      lib.mapAttrs' (
        name: text:
          lib.nameValuePair ".codex/prompts/${name}.md" {
            inherit text;
          }
      )
      commands;
    nonoProfile = mkNonoProfile {
      name = "codex";
      description = "Codex CLI coding agent profile with restricted network, Codex/OpenAI access, executor.sh MCP access, and NixOS development tooling.";
      writablePaths = [
        "$HOME/.cache/codex"
        "$HOME/.codex"
        "$HOME/.local/share/codex"
        "$HOME/.local/state/codex"
      ];
      bypassProtection = [
        "$HOME/.codex"
      ];
      serviceDomains = [
        "api.openai.com"
        "auth.openai.com"
        "chatgpt.com"
        "*.chatgpt.com"
      ];
      additionalDomains = [
        "openai.com"
        "*.openai.com"
      ];
      apiEnvironmentVariables = [
        "OPENAI_*"
      ];
    };
    plannotatorHook = {
      hooks.Stop = [
        {
          hooks = [
            {
              type = "command";
              command = lib.getExe inputs'.llm-agents.packages.plannotator;
              timeout = 345600;
            }
          ];
        }
      ];
    };
    configs = {
      ".codex/config.toml".source = tomlFormat.generate "codex-config.toml" (import ./_codex/settings.nix {
        homeDirectory = config.home.homeDirectory;
      });
      ".codex/hooks.json".source = jsonFormat.generate "codex-hooks.json" plannotatorHook;
      ".config/nono/profiles/codex.json".source = jsonFormat.generate "nono-codex-profile.json" nonoProfile;
    };
  in {
    home = {
      packages = [
        inputs'.llm-agents.packages.codex
        inputs'.llm-agents.packages.plannotator
      ];
      shellAliases.ncodex = "nono run --profile codex --allow-cwd -- codex --sandbox danger-full-access --ask-for-approval on-request";
      file = commandFiles // configs;
    };
  };
}
