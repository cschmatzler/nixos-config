rec {
	user = {
		name = "cschmatzler";
		fullName = "Christoph Schmatzler";
		emails = {
			personal = "christoph@schmatzler.com";
			work = "christoph@tuist.dev";
			icloud = "christoph.schmatzler@icloud.com";
		};
		ssh.authorizedKeys = [
			"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHfRZQ+7ejD3YHbyMTrV0gN1Gc0DxtGgl5CVZSupo5ws"
			"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL/I+/2QT47raegzMIyhwMEPKarJP/+Ox9ewA4ZFJwk/"
		];
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
		janet = mkHost "aarch64-darwin";
		tahani = mkHost "x86_64-linux";
	};

	tailscaleDomain = "manticore-hippocampus.ts.net";
	tailscaleHost = name: "${name}.${tailscaleDomain}";
}
