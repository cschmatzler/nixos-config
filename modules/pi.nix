_: {
  den.aspects.pi.homeManager = {
    inputs',
    lib,
    pkgs,
    ...
  }: let
    jsonFormat = pkgs.formats.json {};
    mkNonoProfile = import ./_ai/nono-profile.nix;
    commands = import ./_ai/commands.nix {frontmatter = false;};
    skillNames = [
      "wrdn-authz"
      "wrdn-code-execution"
      "wrdn-data-exfil"
      "wrdn-gha-workflows"
      "wrdn-pii"
    ];
    promptFiles =
      lib.mapAttrs' (
        name: text:
          lib.nameValuePair ".pi/agent/prompts/${name}.md" {
            inherit text;
          }
      )
      commands;
    skillFiles = builtins.listToAttrs (map (name: {
        name = ".pi/agent/skills/${name}";
        value = {
          source = ./_skills + "/${name}";
          recursive = true;
        };
      })
      skillNames);
    settings = {
      theme = "light";
      quietStartup = true;
      hideThinkingBlock = true;
      defaultProvider = "openai-codex";
      defaultModel = "gpt-5.6-sol";
      defaultThinkingLevel = "high";
      enableInstallTelemetry = false;
      packages = [
        "git:github.com/dmmulroy/pi-mcp"
        "npm:pi-subagents"
      ];
      prompts = ["./prompts"];
      skills = ["./skills"];
    };
    nonoProfile = mkNonoProfile {
      name = "pi";
      description = "Pi coding agent profile with restricted network, OpenAI access, executor.sh MCP access, and NixOS development tooling.";
      writablePaths = [
        "$HOME/.cache/pi"
        "$HOME/.pi"
        "$HOME/.local/share/pi"
        "$HOME/.local/state/pi"
      ];
      bypassProtection = [
        "$HOME/.pi"
      ];
      serviceDomains = [
        "api.openai.com"
        "auth.openai.com"
        "chatgpt.com"
        "*.chatgpt.com"
        "pi.dev"
        "*.pi.dev"
      ];
      additionalDomains = [
        "openai.com"
        "*.openai.com"
      ];
      apiEnvironmentVariables = [
        "OPENAI_*"
        "PI_*"
      ];
    };
    configs = {
      ".pi/agent/settings.json".source = jsonFormat.generate "pi-settings.json" settings;
      ".pi/agent/mcp.json".source = jsonFormat.generate "pi-mcp.json" (import ./_ai/mcp.nix {client = "pi";});
      # Vendored from mitsuhiko/agent-stuff at 4bce45560fa55ace2f5dc8634a63a2af464ddc8b.
      ".pi/agent/extensions/review.ts".source = ./_pi/extensions/review.ts;
      ".config/nono/profiles/pi.json".source = jsonFormat.generate "nono-pi-profile.json" nonoProfile;
    };
  in {
    programs.fish.shellInit = lib.mkAfter ''
      set -gx PI_SKIP_VERSION_CHECK 1
    '';

    home = {
      packages = [
        inputs'.llm-agents.packages.pi
      ];
      shellAliases.npi = "nono run --profile pi --allow-cwd -- pi";
      file =
        promptFiles
        // skillFiles
        // configs;
    };
  };
}
