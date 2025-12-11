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
		../../profiles/core.nix
		../../profiles/fail2ban.nix
		../../profiles/gitea.nix
		../../profiles/nixos.nix
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

	networking.hostName = hostname;
}
