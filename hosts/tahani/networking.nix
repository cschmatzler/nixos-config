{config, ...}: {
	networking = {
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
			trustedInterfaces = ["tailscale0"];
			allowedUDPPorts = [config.services.tailscale.port];
			allowedTCPPorts = [22];
			checkReversePath = "loose";
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
}
