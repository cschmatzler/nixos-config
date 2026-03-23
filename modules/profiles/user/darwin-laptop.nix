{den, ...}: {
	den.aspects.user-darwin-laptop = {
		includes = [
			den.aspects.user-workstation
			den.aspects.desktop
		];

		homeManager = {
			fonts.fontconfig.enable = true;
		};
	};
}
