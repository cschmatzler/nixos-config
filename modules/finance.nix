{...}: {
	den.aspects.finance.homeManager = {pkgs, ...}: {
		home.packages = [pkgs.hledger];
	};
}
