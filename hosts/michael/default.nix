{
	modulesPath,
	hostname,
	inputs,
	user,
	pkgs,
	constants,
	...
}: {
	imports = [
		(modulesPath + "/installer/scan/not-detected.nix")
		(modulesPath + "/profiles/qemu-guest.nix")
		./disk-config.nix
		./hardware-configuration.nix
		../../modules/core.nix
		../../modules/nixos.nix
		inputs.disko.nixosModules.disko
	];

	home-manager.users.${user} = {
		pkgs,
		lib,
		...
	}: {
		_module.args = {inherit user constants inputs;};
		imports = [
			inputs.nixvim.homeModules.nixvim
			../../modules/bash.nix
			../../modules/bat.nix
			../../modules/direnv.nix
			../../modules/eza.nix
			../../modules/fish.nix
			../../modules/fzf.nix
			../../modules/git.nix
			../../modules/home.nix
			../../modules/jjui.nix
			../../modules/jujutsu.nix
			../../modules/lazygit.nix
			../../modules/neovim
			../../modules/ripgrep.nix
			../../modules/ssh.nix
			../../modules/starship.nix
			../../modules/zoxide.nix
		];
	};

	networking.firewall.allowedTCPPorts = [80 443];

	services.gitea = {
		enable = true;
		database = {
			type = "sqlite3";
			path = "/var/lib/gitea/data/gitea.db";
		};
		settings = {
			server = {
				ROOT_URL = "https://git.schmatzler.com/";
				DOMAIN = "git.schmatzler.com";
				HTTP_ADDR = "127.0.0.1";
				HTTP_PORT = 3000;
			};
			service.DISABLE_REGISTRATION = true;
		};
	};

	services.caddy = {
		enable = true;
		virtualHosts."git.schmatzler.com".extraConfig = ''
			reverse_proxy localhost:3000
		'';
	};

	services.openssh = {
		enable = true;
		settings = {
			PermitRootLogin = "yes";
			PasswordAuthentication = false;
		};
	};

	networking.hostName = hostname;
}
