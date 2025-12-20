{
	inputs,
	pkgs,
	user,
	constants,
	...
}: {
	imports = [
		./adguardhome.nix
		./networking.nix
		./openssh.nix
		./paperless.nix
		./secrets.nix
		./syncthing.nix
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
			inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.amp
			inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.beads
		];

		programs.git.settings.user.email = "christoph@schmatzler.com";
	};

	virtualisation.docker.enable = true;
}
