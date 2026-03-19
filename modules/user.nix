{den, ...}: {
	den.aspects.cschmatzler.includes = [
		den.provides.primary-user
	];

	den.aspects.cschmatzler.homeManager = {
		...
	}: {
		programs.home-manager.enable = true;
	};
}
