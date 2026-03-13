{inputs, ...}: {
	den.aspects.nixos-system.nixos = {pkgs, ...}: {
		imports = [inputs.home-manager.nixosModules.home-manager];

		security.sudo.enable = true;
		security.sudo.extraRules = [
			{
				users = ["cschmatzler"];
				commands = [
					{
						command = "/run/current-system/sw/bin/nix-env";
						options = ["NOPASSWD"];
					}
					{
						command = "/nix/store/*/bin/switch-to-configuration";
						options = ["NOPASSWD"];
					}
					{
						command = "/nix/store/*/bin/activate";
						options = ["NOPASSWD"];
					}
					{
						command = "/nix/store/*/bin/activate-rs";
						options = ["NOPASSWD"];
					}
					{
						command = "/nix/store/*/activate-rs";
						options = ["NOPASSWD"];
					}
					{
						command = "/nix/store/*/bin/wait-activate";
						options = ["NOPASSWD"];
					}
					{
						command = "/nix/store/*/wait-activate";
						options = ["NOPASSWD"];
					}
					{
						command = "/run/current-system/sw/bin/rm /tmp/deploy-rs-canary-*";
						options = ["NOPASSWD"];
					}
				];
			}
		];

		time.timeZone = "UTC";

		nix = {
			settings.trusted-users = ["cschmatzler"];
			gc.dates = "weekly";
			nixPath = ["nixos-config=/home/cschmatzler/.local/share/src/nixos-config:/etc/nixos"];
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
			kernelPackages = pkgs.linuxPackages;
		};

		users.users = {
			cschmatzler = {
				isNormalUser = true;
				home = "/home/cschmatzler";
				extraGroups = [
					"wheel"
					"sudo"
					"network"
					"systemd-journal"
				];
				shell = pkgs.nushell;
				openssh.authorizedKeys.keys = [
					"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHfRZQ+7ejD3YHbyMTrV0gN1Gc0DxtGgl5CVZSupo5ws"
					"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL/I+/2QT47raegzMIyhwMEPKarJP/+Ox9ewA4ZFJwk/"
				];
			};
			root = {
				openssh.authorizedKeys.keys = [
					"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHfRZQ+7ejD3YHbyMTrV0gN1Gc0DxtGgl5CVZSupo5ws"
					"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL/I+/2QT47raegzMIyhwMEPKarJP/+Ox9ewA4ZFJwk/"
				];
			};
		};

		home-manager.useGlobalPkgs = true;
	};
}
