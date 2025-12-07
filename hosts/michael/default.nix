{
	modulesPath,
	hostname,
	inputs,
	...
}: {
	imports = [
		(modulesPath + "/installer/scan/not-detected.nix")
		(modulesPath + "/profiles/qemu-guest.nix")
		./disk-config.nix
		./hardware-configuration.nix
		../../modules/nixos
		inputs.disko.nixosModules.disko
		inputs.tangled.nixosModules.knot
	];

	services.tangled.knot = {
		enable = true;
		server = {
			hostname = "knot.schmatzler.com";
			owner = "did:plc:yiapylv5gwzlyzesppjmukvj";
		};
	};

	networking.firewall.allowedTCPPorts = [ 5444 5555 ];

	services.openssh = {
		enable = true;
		settings = {
			PermitRootLogin = "yes";
			PasswordAuthentication = false;
		};
	};

	networking.hostName = hostname;
}
