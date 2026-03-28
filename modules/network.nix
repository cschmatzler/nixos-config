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

	den.aspects.fail2ban.nixos = {
		services.fail2ban = {
			enable = true;
			maxretry = 5;
			bantime = "10m";
			bantime-increment = {
				enable = true;
				multipliers = "1 2 4 8 16 32 64";
				maxtime = "168h";
				overalljails = true;
			};
			jails = {
				sshd.settings = {
					enabled = true;
					port = "ssh";
					filter = "sshd";
					maxretry = 3;
				};
				gitea.settings = {
					enabled = true;
					filter = "gitea";
					logpath = "/var/lib/gitea/log/gitea.log";
					maxretry = 10;
					findtime = 3600;
					bantime = 900;
					action = "iptables-allports";
				};
			};
		};

		environment.etc."fail2ban/filter.d/gitea.local".text = ''
			[Definition]
			failregex = .*(Failed authentication attempt|invalid credentials|Attempted access of unknown user).* from <HOST>
			ignoreregex =
		'';
	};

	den.aspects.tailscale.nixos = {
		services.tailscale = {
			enable = true;
			openFirewall = true;
			permitCertUid = "caddy";
			useRoutingFeatures = "server";
		};
	};

	den.aspects.tailscale.darwin = {
		services.tailscale.enable = true;
	};
}
