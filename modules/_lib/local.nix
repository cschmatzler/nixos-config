rec {
	user = {
		name = "cschmatzler";
		fullName = "Christoph Schmatzler";
		emails = {
			personal = "christoph@schmatzler.com";
			work = "christoph@tuist.dev";
			icloud = "christoph.schmatzler@icloud.com";
		};
	};

	secretPath = name: "/run/secrets/${name}";

	mkHome = system:
		if builtins.match ".*-darwin" system != null
		then "/Users/${user.name}"
		else "/home/${user.name}";

	mkHost = system: {
		inherit system;
		home = mkHome system;
	};

	hosts = {
		chidi = mkHost "aarch64-darwin";
		janet = mkHost "aarch64-darwin";
		michael = mkHost "x86_64-linux";
		tahani = mkHost "x86_64-linux";
	};

	tailscaleDomain = "manticore-hippocampus.ts.net";
	tailscaleHost = name: "${name}.${tailscaleDomain}";
}
