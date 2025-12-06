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

	services.openssh = {
		enable = true;
		settings = {
			PermitRootLogin = "yes";
			PasswordAuthentication = false;
		};
	};

	boot.loader.grub = {
		enable = true;
		efiSupport = true;
		efiInstallAsRemovable = true;
	};

	networking.hostName = hostname;
}
