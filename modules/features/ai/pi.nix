{
  den,
  inputs,
  ...
}: {
  # Keep Pi current without changing the other agents' existing pins.
  flake-file.inputs.pi-packages = {
    url = "github:numtide/llm-agents.nix";
    inputs = {
      nixpkgs.follows = "nixpkgs";
      flake-parts.follows = "flake-parts";
      systems.follows = "llm-agents/systems";
      treefmt-nix.follows = "llm-agents/treefmt-nix";
      bun2nix.follows = "llm-agents/bun2nix";
    };
  };
  den.aspects.pi = {
    includes = [den.aspects.dev-tools];

    homeManager = {
      config,
      inputs',
      pkgs,
      ...
    }: let
      theme = import ../../_lib/theme.nix;
      json = pkgs.formats.json {};
    in {
      home.packages = [inputs'.pi-packages.packages.pi];

      home.file = {
        ".pi/agent/settings.json".source = json.generate "pi-settings.json" {
          theme = theme.slug;
          quietStartup = true;
          hideThinkingBlock = true;
          showCacheMissNotices = true;
          defaultProvider = "openai-codex";
          defaultModel = "gpt-5.6-sol";
          defaultThinkingLevel = "medium";
          enableInstallTelemetry = false;
          packages = [
            "./packages/pi-herdr"
            "npm:@ff-labs/pi-fff"
            "npm:mattpocock-skills-unofficial-plugin"
            "npm:@juicesharp/rpiv-ask-user-question"
            "npm:pi-web-access"
            "npm:pi-claude-bridge@0.9.3"
          ];
          prompts = ["./prompts"];
          skills = ["./skills"];
        };

        ".pi/agent/mcp.json".source = json.generate "pi-mcp.json" {
          mcpServers =
            config.programs.mcp.servers
            // {
              homeassistant = config.programs.claude-code.mcpServers.homeassistant;
            };
        };

        ".pi/agent/claude-bridge.json".source = json.generate "pi-claude-bridge.json" {
          provider = {
            # Use the Max subscription context limits.
            plan = "max";
            pathToClaudeCodeExecutable = "${config.programs.claude-code.package}/bin/claude";
          };
        };

        ".pi/agent/themes/${theme.slug}.json".source = json.generate "${theme.slug}.json" {
          "$schema" = "https://pi.dev/schemas/theme.schema.json";
          name = theme.slug;
          vars = theme.hex;
          colors = {
            accent = "iris";
            border = "highlightHigh";
            borderAccent = "iris";
            borderMuted = "highlightMed";
            success = "leaf";
            error = "love";
            warning = "gold";
            muted = "subtle";
            dim = "muted";
            text = "text";
            thinkingText = "subtle";

            selectedBg = "highlightMed";
            scrollbarThumb = "highlightHigh";
            searchMatchBg = "gold";
            searchMatchText = "base";
            userMessageBg = "surface";
            userMessageText = "text";
            customMessageBg = "overlay";
            customMessageText = "text";
            customMessageLabel = "foam";
            toolPendingBg = "overlay";
            toolSuccessBg = "surface";
            toolErrorBg = "surface";
            toolTitle = "iris";
            toolOutput = "subtle";

            mdHeading = "iris";
            mdLink = "foam";
            mdLinkUrl = "subtle";
            mdCode = "gold";
            mdCodeBlock = "text";
            mdCodeBlockBorder = "muted";
            mdQuote = "subtle";
            mdQuoteBorder = "muted";
            mdHr = "muted";
            mdListBullet = "rose";

            toolDiffAdded = "leaf";
            toolDiffRemoved = "love";
            toolDiffContext = "subtle";

            syntaxComment = "muted";
            syntaxKeyword = "pine";
            syntaxFunction = "rose";
            syntaxVariable = "text";
            syntaxString = "gold";
            syntaxNumber = "gold";
            syntaxType = "foam";
            syntaxOperator = "subtle";
            syntaxPunctuation = "subtle";

            thinkingOff = "muted";
            thinkingMinimal = "subtle";
            thinkingLow = "pine";
            thinkingMedium = "foam";
            thinkingHigh = "iris";
            thinkingXhigh = "love";
            thinkingMax = "rose";
            bashMode = "gold";
          };
          export = {
            pageBg = theme.hex.base;
            cardBg = theme.hex.surface;
            infoBg = theme.hex.overlay;
          };
        };

        ".pi/agent/packages/pi-herdr" = {
          source = ./_pi/packages/pi-herdr;
          recursive = true;
        };
        ".pi/agent/prompts" = {
          source = ./_agents/prompts;
          recursive = true;
        };
        ".pi/agent/skills" = {
          source = pkgs.linkFarm "pi-skills" (pkgs.lib.mapAttrsToList (name: path: {inherit name path;}) (import ./_agents/skills.nix {
            inherit inputs;
            lib = pkgs.lib;
          }));
        };
        ".pi/agent/extensions" = {
          source = ./_pi/extensions;
          recursive = true;
        };
      };
    };
  };
}
