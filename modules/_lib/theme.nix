{
  catppuccinMocha = rec {
    slug = "catppuccin-mocha";
    displayName = "Catppuccin Mocha";
    fishThemeName = slug;
    ghosttyThemeName = displayName;
    piThemeName = slug;
    piPackage = "npm:@sherif-fanous/pi-catppuccin";
    deltaSyntaxTheme = displayName;

    neovim = {
      colorscheme = "catppuccin";
      flavour = "mocha";
      variant = "mocha";
    };

    hex = rec {
      rosewater = "#f5e0dc";
      flamingo = "#f2cdcd";
      pink = "#f5c2e7";
      mauve = "#cba6f7";
      red = "#f38ba8";
      maroon = "#eba0ac";
      peach = "#fab387";
      yellow = "#f9e2af";
      green = "#a6e3a1";
      teal = "#94e2d5";
      sky = "#89dceb";
      sapphire = "#74c7ec";
      blue = "#89b4fa";
      lavender = "#b4befe";
      text = "#cdd6f4";
      subtext1 = "#bac2de";
      subtext0 = "#a6adc8";
      overlay2 = "#9399b2";
      overlay1 = "#7f849c";
      overlay0 = "#6c7086";
      surface2 = "#585b70";
      surface1 = "#45475a";
      surface0 = "#313244";
      base = "#1e1e2e";
      mantle = "#181825";
      crust = "#11111b";

      love = red;
      gold = yellow;
      rose = rosewater;
      pine = maroon;
      foam = teal;
      iris = mauve;
      leaf = green;
      subtle = subtext1;
      muted = overlay1;
      highlightHigh = surface2;
      highlightMed = surface1;
      highlightLow = surface0;
      overlay = surface0;
      surface = mantle;
    };

    rgb = rec {
      rosewater = "245 224 220";
      flamingo = "242 205 205";
      pink = "245 194 231";
      mauve = "203 166 247";
      red = "243 139 168";
      maroon = "235 160 172";
      peach = "250 179 135";
      yellow = "249 226 175";
      green = "166 227 161";
      teal = "148 226 213";
      sky = "137 220 235";
      sapphire = "116 199 236";
      blue = "137 180 250";
      lavender = "180 190 254";
      text = "205 214 244";
      subtext1 = "186 194 222";
      subtext0 = "166 173 200";
      overlay2 = "147 153 178";
      overlay1 = "127 132 156";
      overlay0 = "108 112 134";
      surface2 = "88 91 112";
      surface1 = "69 71 90";
      surface0 = "49 50 68";
      base = "30 30 46";
      mantle = "24 24 37";
      crust = "17 17 27";
      black = "0 0 0";

      love = red;
      gold = yellow;
      rose = rosewater;
      pine = maroon;
      foam = teal;
      iris = mauve;
      leaf = green;
      subtle = subtext1;
      muted = overlay1;
      highlightHigh = surface2;
      highlightMed = surface1;
      highlightLow = surface0;
      overlay = surface0;
      surface = mantle;
    };
  };
}
