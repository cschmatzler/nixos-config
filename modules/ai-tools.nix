{den, ...}: {
	den.aspects.ai-tools = {
		includes = [
			den.aspects.ai-api-key
			den.aspects.pi
			den.aspects.ynab
		];

		homeManager = {pkgs, ...}: {
			home.packages = with pkgs; [
				nono
			];
		};
	};
}
