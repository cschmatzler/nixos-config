{
	inputs,
	config,
	...
}: let
	local = import ./_lib/local.nix;
in {
	flake.deploy.nodes = {
		michael = {
			hostname = "michael";
			sshUser = local.user.name;
			profiles.system = {
				user = "root";
				path = inputs.deploy-rs.lib.x86_64-linux.activate.nixos config.flake.nixosConfigurations.michael;
			};
		};
		tahani = {
			hostname = "tahani";
			sshUser = local.user.name;
			profiles.system = {
				user = "root";
				path = inputs.deploy-rs.lib.x86_64-linux.activate.nixos config.flake.nixosConfigurations.tahani;
			};
		};
	};

	flake.checks.x86_64-linux = inputs.deploy-rs.lib.x86_64-linux.deployChecks config.flake.deploy;
}
