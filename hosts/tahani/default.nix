{
	config,
	hostname,
	user,
	inputs,
	...
}: {
	imports = [
		../../modules/nixos
		inputs.tangled.nixosModules.knot
	];

	services.adguardhome = {
		enable = true;
		port = 10000;
		settings = {
			dns = {
				upstream_dns = [
					"1.1.1.1"
					"1.0.0.1"
				];
			};
			filtering = {
				protection_enabled = true;
				filtering_enabled = true;
				safe_search = {
					enabled = false;
				};
			};
		};
	};

	services.tangled.knot = {
		enable = true;
		server = {
			hostname = "knot.schmatzler.com";
			owner = "did:plc:yiapylv5gwzlyzesppjmukvj";
		};
	};

	virtualisation.docker = {
		enable = true;
	};

	services.openssh = {
		enable = true;
		settings = {
			PermitRootLogin = "yes";
			PasswordAuthentication = false;
		};
	};

	fileSystems."/" = {
		device = "/dev/disk/by-label/NIXROOT";
		fsType = "ext4";
	};

	fileSystems."/boot" = {
		device = "/dev/disk/by-label/NIXBOOT";
		fsType = "vfat";
	};

	networking = {
		hostName = hostname;
		useDHCP = false;
		interfaces.eno1.ipv4.addresses = [
			{
				address = "192.168.1.10";
				prefixLength = 24;
			}
		];
		defaultGateway = "192.168.1.1";
		nameservers = ["1.1.1.1"];
		firewall = {
			enable = true;
			trustedInterfaces = ["eno1" "tailscale0"];
			allowedUDPPorts = [config.services.tailscale.port];
			allowedTCPPorts = [22 5555];
			checkReversePath = "loose";
		};
	};

	sops.secrets = {
		tahani-syncthing-cert = {
			sopsFile = ../../secrets/tahani-syncthing-cert;
			format = "binary";
			owner = user;
			path = "/home/${user}/.config/syncthing/cert.pem";
		};
		tahani-syncthing-key = {
			sopsFile = ../../secrets/tahani-syncthing-key;
			format = "binary";
			owner = user;
			path = "/home/${user}/.config/syncthing/key.pem";
		};
	};

	services.syncthing.settings.folders = {
		"Projects/Personal" = {
			path = "/home/${user}/Projects/Personal";
			devices = ["tahani" "jason"];
		};
		"Projects/Work" = {
			path = "/home/${user}/Projects/Work";
			devices = ["tahani" "chidi"];
		};
	};

	home-manager.users.${user} = {
		programs.git.settings.user.email = "christoph@schmatzler.com";
	};
}
