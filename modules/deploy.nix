{
	inputs,
	config,
	...
}: {
	flake.deploy.nodes = {
		michael = {
			hostname = "michael";
			sshUser = "cschmatzler";
			profiles.system = {
				user = "root";
				path = inputs.deploy-rs.lib.x86_64-linux.activate.nixos config.flake.nixosConfigurations.michael;
			};
		};
		tahani = {
			hostname = "tahani";
			sshUser = "cschmatzler";
			profiles.system = {
				user = "root";
				path = inputs.deploy-rs.lib.x86_64-linux.activate.nixos config.flake.nixosConfigurations.tahani;
			};
		};
	};

	flake.checks.x86_64-linux = inputs.deploy-rs.lib.x86_64-linux.deployChecks config.flake.deploy;
}
