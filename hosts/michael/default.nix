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
		../../modules/gitea.nix
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

	services.openssh = {
		enable = true;
		settings = {
			PermitRootLogin = "yes";
			PasswordAuthentication = false;
		};
	};

	networking.hostName = hostname;
}
