{
	pkgs,
	inputs,
	user,
	constants,
	...
}: {
	security.sudo.enable = true;
	security.sudo.extraRules = [
		{
			users = [user];
			commands = [
				{
					command = "/run/current-system/sw/bin/nix-env";
					options = ["NOPASSWD"];
				}
				{
					command = "/nix/store/*/bin/switch-to-configuration";
					options = ["NOPASSWD"];
				}
			];
		}
	];

	system.stateVersion = constants.stateVersions.nixos;
	time.timeZone = "UTC";

	home-manager.sharedModules = [
		{_module.args = {inherit user constants inputs;};}
	];

	nix = {
		settings.trusted-users = [user];
		gc.dates = "weekly";
		nixPath = ["nixos-config=/home/${user}/.local/share/src/nixos-config:/etc/nixos"];
	};

	boot = {
		loader = {
			systemd-boot = {
				enable = true;
				configurationLimit = 42;
			};
			efi.canTouchEfiVariables = true;
		};
		initrd.availableKernelModules = [
			"xhci_pci"
			"ahci"
			"nvme"
			"usbhid"
			"usb_storage"
			"sd_mod"
		];
		kernelPackages = pkgs.linuxPackages_latest;
	};

	sops.age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];

	users.users = {
		${user} = {
			isNormalUser = true;
			home = "/home/${user}";
			extraGroups = [
				"wheel"
				"sudo"
				"network"
				"systemd-journal"
			];
			shell = pkgs.nushell;
			openssh.authorizedKeys.keys = constants.sshKeys;
		};

		root = {
			openssh.authorizedKeys.keys = constants.sshKeys;
		};
	};

	home-manager.useGlobalPkgs = true;
}
