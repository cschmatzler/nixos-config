{
	pkgs,
	constants,
	inputs,
	...
}: {
	imports = [
		./atuin.nix
		./bash.nix
		./bat.nix
		./direnv.nix
		./eza.nix
		./fish.nix
		./fzf.nix
		./git.nix
		./jjui.nix
		./jujutsu.nix
		./lazygit.nix
		./mise.nix
		./neovim
		./opencode.nix
		./ripgrep.nix
		./ssh.nix
		./starship.nix
		./zellij.nix
		./zk.nix
		./zoxide.nix
		./zsh.nix
	];

	programs.home-manager.enable = true;

	home = {
		packages = pkgs.callPackage ../packages.nix {inherit inputs;};
		stateVersion = constants.stateVersions.homeManager;
	};
}
