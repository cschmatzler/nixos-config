{...}: {
	den.aspects.openssh.nixos = {
		services.openssh = {
			enable = true;
			settings = {
				PermitRootLogin = "no";
				PasswordAuthentication = false;
			};
		};
	};

	den.aspects.tailscale.nixos = {
		services.tailscale = {
			enable = true;
			extraSetFlags = ["--ssh"];
			openFirewall = true;
			permitCertUid = "caddy";
			useRoutingFeatures = "server";
		};
	};

	den.aspects.tailscale.darwin = {pkgs, ...}: {
		environment.systemPackages = [pkgs.tailscale-gui];
	};
}
