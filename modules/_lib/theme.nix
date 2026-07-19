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
  };
}
