{den, ...}: {
  den.aspects.pi = {
    includes = [den.aspects.dev-tools];

    homeManager = {
      inputs',
      pkgs,
      ...
    }: let
      theme = import ../../_lib/theme.nix;
      json = pkgs.formats.json {};
    in {
      home.packages = [inputs'.llm-agents.packages.pi];

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
            "git:github.com/dmmulroy/pi-mcp@761c81dc5d4e0745f4ae77dcacb1be5517b18101"
            "npm:@ff-labs/pi-fff"
            "npm:mattpocock-skills-unofficial-plugin"
            "npm:@juicesharp/rpiv-ask-user-question"
            "npm:pi-web-access"
            "npm:@gotgenes/pi-anthropic-auth"
            "npm:@plannotator/pi-extension"
          ];
          prompts = ["./prompts"];
          skills = ["./skills"];
        };

        ".pi/agent/mcp.json".source = json.generate "pi-mcp.json" {
          mcp = {
            toolMode = "direct";
            startup = "eager";
            servers = {
              opensrc = {
                type = "local";
                command = ["npx" "-y" "opensrc-mcp"];
                enabled = true;
              };
              executor = {
                type = "remote";
                url = "https://executor.manticore-hippocampus.ts.net/mcp/toolkits/general";
                enabled = true;
              };
            };
          };
        };

        ".pi/agent/themes/${theme.slug}.json".source = json.generate "${theme.slug}.json" {
          "$schema" = "https://raw.githubusercontent.com/earendil-works/pi/main/packages/coding-agent/src/modes/interactive/theme/theme-schema.json";
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
          source = ./_pi/prompts;
          recursive = true;
        };
        ".pi/agent/skills" = {
          source = ./_pi/skills;
          recursive = true;
        };
        ".pi/agent/extensions" = {
          source = ./_pi/extensions;
          recursive = true;
        };
      };
    };
  };
}
