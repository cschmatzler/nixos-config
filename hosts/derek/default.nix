{
	pkgs,
	inputs,
	user,
	hostname,
	modulesPath,
	...
}: {
	imports = [
		(modulesPath + "/installer/scan/not-detected.nix")
		(modulesPath + "/profiles/qemu-guest.nix")
		./disk-config.nix
		./hardware-configuration.nix
		./secrets.nix
		../../profiles/core.nix
		../../profiles/fail2ban.nix
		../../profiles/nixos.nix
		../../profiles/openssh.nix
		../../profiles/tailscale.nix
		inputs.disko.nixosModules.disko
		inputs.sops-nix.nixosModules.sops
	];

	networking.hostName = hostname;

	environment.systemPackages = with pkgs; [
		chromium
		playwright-driver.browsers
	];

	home-manager.users.${user} = {
		imports = [
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
			./calendar.nix
			inputs.nixvim.homeModules.nixvim
		];
	};
}
