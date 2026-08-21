{
  rosePineDawn = rec {
    slug = "rose-pine-dawn";
    displayName = "Rosé Pine Dawn";
    fishThemeName = displayName;
    ghosttyThemeName = "Rose Pine Dawn";
    deltaSyntaxTheme = displayName;

    neovim = {
      colorscheme = "rose-pine";
      variant = "dawn";
    };

    hex = {
      base = "#faf4ed";
      surface = "#fffaf3";
      overlay = "#f2e9e1";
      muted = "#9893a5";
      subtle = "#797593";
      text = "#575279";
      love = "#b4637a";
      gold = "#ea9d34";
      rose = "#d7827e";
      pine = "#286983";
      foam = "#56949f";
      iris = "#907aa9";
      leaf = "#6d8f89";
      highlightLow = "#f4ede8";
      highlightMed = "#dfdad9";
      highlightHigh = "#cecacd";
    };

    pi = {
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
        pageBg = hex.base;
        cardBg = hex.surface;
        infoBg = hex.overlay;
      };
    };
  };
}
