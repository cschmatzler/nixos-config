{
  rosePine = rec {
    slug = "rose-pine";
    displayName = "Rosé Pine";
    fishThemeName = displayName;
    ghosttyThemeName = "Rose Pine";
    deltaSyntaxTheme = displayName;

    neovim = {
      colorscheme = "rose-pine";
      variant = "main";
    };

    hex = {
      base = "#191724";
      surface = "#1f1d2e";
      overlay = "#26233a";
      muted = "#6e6a86";
      subtle = "#908caa";
      text = "#e0def4";
      love = "#eb6f92";
      gold = "#f6c177";
      rose = "#ebbcba";
      pine = "#31748f";
      foam = "#9ccfd8";
      iris = "#c4a7e7";
      leaf = "#95b1ac";
      highlightLow = "#21202e";
      highlightMed = "#403d52";
      highlightHigh = "#524f67";
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
