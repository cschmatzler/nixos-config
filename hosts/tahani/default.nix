{
	pkgs,
	inputs,
	user,
	hostname,
	...
}: {
	imports = [
		./adguardhome.nix
		./cache.nix
		./networking.nix
		./paperless.nix
		./secrets.nix
		../../profiles/core.nix
		../../profiles/nixos.nix
		../../profiles/openssh.nix
		../../profiles/tailscale.nix
		inputs.sops-nix.nixosModules.sops
	];

	networking.hostName = hostname;

	home-manager.users.${user} = {
		imports = [
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
			../../profiles/lumen.nix
			../../profiles/mise.nix
			../../profiles/neovim
			../../profiles/opencode.nix
			../../profiles/ripgrep.nix
			../../profiles/ssh.nix
			../../profiles/starship.nix
			../../profiles/zk.nix
			../../profiles/zoxide.nix
			../../profiles/zsh.nix
			inputs.nixvim.homeModules.nixvim
		];

		programs.git.settings.user.email = "christoph@schmatzler.com";
	};

	virtualisation.docker.enable = true;

	swapDevices = [
		{
			device = "/swapfile";
			size = 16 * 1024;
		}
	];
}
