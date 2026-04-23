{
	inputs,
	config,
	...
}: let
	local = import ./_lib/local.nix;
	acceptNewHostKeys = [
		"-o"
		"StrictHostKeyChecking=accept-new"
	];
	mkSystemNode = {
		hostname,
		host,
	}: {
		inherit hostname;
		sshUser = local.user.name;
		sshOpts = acceptNewHostKeys;
		profiles.system = {
			user = "root";
			path = inputs.deploy-rs.lib.x86_64-linux.activate.nixos config.flake.nixosConfigurations.${host};
		};
	};
in {
	flake.deploy.nodes = {
		tahani =
			mkSystemNode {
				hostname = "127.0.0.1";
				host = "tahani";
			};
	};

	flake.checks.x86_64-linux = inputs.deploy-rs.lib.x86_64-linux.deployChecks config.flake.deploy;
}
