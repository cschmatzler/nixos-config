{
	modulesPath,
	hostname,
	inputs,
	config,
	user,
	...
}: {
	imports = [
		(modulesPath + "/installer/scan/not-detected.nix")
		(modulesPath + "/profiles/qemu-guest.nix")
		./disk-config.nix
		./hardware-configuration.nix
		./secrets.nix
		../../modules/gitea.nix
		../../profiles/core.nix
		../../profiles/openssh.nix
		../../profiles/fail2ban.nix
		../../profiles/nixos.nix
		../../profiles/tailscale.nix
		inputs.disko.nixosModules.disko
		inputs.sops-nix.nixosModules.sops
	];

	my.gitea = {
		enable = true;
		litestream = {
			bucket = "michael-gitea-litestream";
			secretFile = config.sops.secrets.michael-gitea-litestream.path;
		};
		restic = {
			bucket = "michael-gitea-repositories";
			passwordFile = config.sops.secrets.michael-gitea-restic-password.path;
			environmentFile = config.sops.secrets.michael-gitea-restic-env.path;
		};
	};

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

	networking.hostName = hostname;
}
