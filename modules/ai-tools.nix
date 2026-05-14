{den, ...}: {
	den.aspects.ai-tools = {
		includes = [
			den.aspects.ai-api-key
			den.aspects.pi
			den.aspects.ynab
		];

		homeManager = {
			pkgs,
			inputs',
			...
		}: {
			home.packages = [
				pkgs.nono
				inputs'.llm-agents.packages.opencode
			];
		};
	};
}
