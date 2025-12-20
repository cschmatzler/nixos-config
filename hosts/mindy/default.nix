{
	modulesPath,
	hostname,
	inputs,
	user,
	constants,
	...
}: {
	imports = [
		(modulesPath + "/installer/scan/not-detected.nix")
		(modulesPath + "/profiles/qemu-guest.nix")
		./disk-config.nix
		./hardware-configuration.nix
		../../modules/pgbackrest.nix
		../../profiles/core.nix
		../../profiles/fail2ban.nix
		../../profiles/nixos.nix
		../../profiles/postgresql.nix
		../../profiles/tailscale.nix
		inputs.disko.nixosModules.disko
		inputs.sops-nix.nixosModules.sops
	];

	sops.secrets.mindy-pgbackrest = {
		sopsFile = ../../secrets/mindy-pgbackrest;
		format = "binary";
		owner = "postgres";
		group = "postgres";
	};

	services.pgbackrest = {
		enable = true;
		secretFile = "/run/secrets/mindy-pgbackrest";
		s3.bucket = "mindy-pgbackrest";
	};

	home-manager.users.${user} = {
		pkgs,
		lib,
		...
	}: {
		_module.args = {inherit user constants inputs;};
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

	services.openssh = {
		enable = true;
		settings = {
			PermitRootLogin = "yes";
			PasswordAuthentication = false;
		};
	};

	virtualisation.docker.enable = true;

	networking.hostName = hostname;
}
