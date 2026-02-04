{
	inputs,
	user,
	hostname,
	...
}: {
	imports = [
		./secrets.nix
		../../profiles/core.nix
		../../profiles/darwin.nix
		../../profiles/dock.nix
		../../profiles/homebrew.nix
		../../profiles/tailscale.nix
		inputs.sops-nix.darwinModules.sops
	];

	networking.hostName = hostname;
	networking.computerName = hostname;

	home-manager.users.${user} = {
		imports = [
			../../profiles/atuin.nix
			../../profiles/aerospace.nix
			../../profiles/bash.nix
			../../profiles/bat.nix
			../../profiles/direnv.nix
			../../profiles/eza.nix
			../../profiles/fish.nix
			../../profiles/fzf.nix
			../../profiles/ghostty.nix
			../../profiles/git.nix
			../../profiles/home.nix
			../../profiles/lazygit.nix
			../../profiles/lumen.nix
			../../profiles/mise.nix
			../../profiles/nono.nix
			../../profiles/neovim
			../../profiles/opencode.nix
			../../profiles/claude-code.nix
			../../profiles/ripgrep.nix
			../../profiles/ssh.nix
			../../profiles/starship.nix
			../../profiles/zk.nix
			../../profiles/zoxide.nix
			../../profiles/zed.nix
			../../profiles/zsh.nix
			inputs.nixvim.homeModules.nixvim
		];
		fonts.fontconfig.enable = true;
		programs.git.settings.user.email = "christoph@schmatzler.com";
	};
}
