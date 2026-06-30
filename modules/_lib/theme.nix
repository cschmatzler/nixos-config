{
	catppuccinLatte = rec {
		slug = "catppuccin-latte";
		displayName = "Catppuccin Latte";
		fishThemeName = slug;
		ghosttyThemeName = displayName;
		opencodeThemeName = slug;
		deltaSyntaxTheme = displayName;

		neovim = {
			colorscheme = "catppuccin";
			flavour = "latte";
			variant = "latte";
		};

		hex = rec {
			rosewater = "#dc8a78";
			flamingo = "#dd7878";
			pink = "#ea76cb";
			mauve = "#8839ef";
			red = "#d20f39";
			maroon = "#e64553";
			peach = "#fe640b";
			yellow = "#df8e1d";
			green = "#40a02b";
			teal = "#179299";
			sky = "#04a5e5";
			sapphire = "#209fb5";
			blue = "#1e66f5";
			lavender = "#7287fd";
			text = "#4c4f69";
			subtext1 = "#5c5f77";
			subtext0 = "#6c6f85";
			overlay2 = "#7c7f93";
			overlay1 = "#8c8fa1";
			overlay0 = "#9ca0b0";
			surface2 = "#acb0be";
			surface1 = "#bcc0cc";
			surface0 = "#ccd0da";
			base = "#eff1f5";
			mantle = "#e6e9ef";
			crust = "#dce0e8";

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
			rosewater = "220 138 120";
			flamingo = "221 120 120";
			pink = "234 118 203";
			mauve = "136 57 239";
			red = "210 15 57";
			maroon = "230 69 83";
			peach = "254 100 11";
			yellow = "223 142 29";
			green = "64 160 43";
			teal = "23 146 153";
			sky = "4 165 229";
			sapphire = "32 159 181";
			blue = "30 102 245";
			lavender = "114 135 253";
			text = "76 79 105";
			subtext1 = "92 95 119";
			subtext0 = "108 111 133";
			overlay2 = "124 127 147";
			overlay1 = "140 143 161";
			overlay0 = "156 160 176";
			surface2 = "172 176 190";
			surface1 = "188 192 204";
			surface0 = "204 208 218";
			base = "239 241 245";
			mantle = "230 233 239";
			crust = "220 224 232";
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
