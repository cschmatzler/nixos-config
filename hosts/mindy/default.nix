{
	modulesPath,
	hostname,
	inputs,
	user,
	...
}: {
	imports = [
		(modulesPath + "/installer/scan/not-detected.nix")
		(modulesPath + "/profiles/qemu-guest.nix")
		./disk-config.nix
		./hardware-configuration.nix
		./pgbackrest.nix
		./secrets.nix
		../../modules/pgbackrest.nix
		../../profiles/core.nix
		../../profiles/openssh.nix
		../../profiles/fail2ban.nix
		../../profiles/nixos.nix
		../../profiles/postgresql.nix
		../../profiles/tailscale.nix
		inputs.disko.nixosModules.disko
		inputs.sops-nix.nixosModules.sops
	];

	home-manager.users.${user} = {
		imports = [
			inputs.nixvim.homeModules.nixvim
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
			../../profiles/neovim
			../../profiles/ripgrep.nix
			../../profiles/ssh.nix
			../../profiles/starship.nix
			../../profiles/zoxide.nix
		];
	};

	virtualisation.docker = {
		enable = true;
		daemon.settings = {
			log-driver = "local";
		};
	};

	networking.hostName = hostname;

	services.postgresql = {
		ensureDatabases = ["shnosh"];
		ensureUsers = [
			{
				name = "shnosh";
				ensureDBOwnership = true;
			}
		];
	};
}
