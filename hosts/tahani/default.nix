{
	config,
	hostname,
	user,
	inputs,
	pkgs,
	constants,
	...
}: {
	imports = [
		../../profiles/core.nix
		../../profiles/nixos.nix
		../../profiles/syncthing.nix
		../../profiles/tailscale.nix
		inputs.sops-nix.nixosModules.sops
	];

	home-manager.users.${user} = {
		pkgs,
		lib,
		...
	}: {
		_module.args = {inherit user constants inputs;};
		imports = [
			inputs.nixvim.homeModules.nixvim
			../../profiles/atuin.nix
			../../profiles/bash.nix
			../../profiles/bat.nix
			../../profiles/direnv.nix
			../../profiles/eza.nix
			../../profiles/fish.nix
			../../profiles/fzf.nix
			../../profiles/git.nix
			../../profiles/home.nix
			../../profiles/jjui.nix
			../../profiles/jujutsu.nix
			../../profiles/lazygit.nix
			../../profiles/mise.nix
			../../profiles/neovim
			../../profiles/opencode.nix
			../../profiles/ripgrep.nix
			../../profiles/ssh.nix
			../../profiles/starship.nix
			../../profiles/zellij.nix
			../../profiles/zk.nix
			../../profiles/zoxide.nix
			../../profiles/zsh.nix
		];

		home.packages = [
			inputs.beads.packages.${pkgs.system}.default
			inputs.nix-ai-tools.packages.${pkgs.system}.amp
		];

		programs.git.settings.user.email = "christoph@schmatzler.com";
	};

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

	virtualisation.docker = {
		enable = true;
	};

	services.openssh = {
		enable = true;
		settings = {
			PermitRootLogin = "prohibit-password";
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

	services.caddy = {
		enable = true;
		virtualHosts."tahani.manticore-hippocampus.ts.net".extraConfig = ''
			respond "OK"
		'';
	};

	# Allow Caddy to fetch Tailscale HTTPS certs
	services.tailscale.permitCertUid = "caddy";
}
