{
	inputs,
	pkgs,
	user,
	constants,
	...
}: {
	imports = [
		../../modules/core.nix
		../../modules/darwin.nix
		../../modules/darwin-syncthing.nix
		../../modules/dock.nix
		../../modules/homebrew.nix
		../../modules/syncthing.nix
		../../modules/tailscale.nix
		inputs.sops-nix.darwinModules.sops
	];

	networking.hostName = "chidi";
	networking.computerName = "Chidi";

	services.syncthing.settings.folders = {
		"Projects/Work" = {
			path = "/Users/${user}/Projects/Work";
			devices = ["tahani" "chidi"];
		};
	};

	home-manager.users.${user} = {
		pkgs,
		lib,
		...
	}: {
		_module.args = {inherit user constants inputs;};
		imports = [
			inputs.nixvim.homeModules.nixvim
			../../modules/atuin.nix
			../../modules/bash.nix
			../../modules/bat.nix
			../../modules/direnv.nix
			../../modules/eza.nix
			../../modules/fish.nix
			../../modules/fzf.nix
			../../modules/ghostty.nix
			../../modules/git.nix
			../../modules/home.nix
			../../modules/jjui.nix
			../../modules/jujutsu.nix
			../../modules/lazygit.nix
			../../modules/mise.nix
			../../modules/neovim
			../../modules/opencode.nix
			../../modules/ripgrep.nix
			../../modules/ssh.nix
			../../modules/starship.nix
			../../modules/zellij.nix
			../../modules/zk.nix
			../../modules/zoxide.nix
			../../modules/zsh.nix
		];
		fonts.fontconfig.enable = true;
		programs.git.settings.user.email = "christoph@tuist.dev";
	};

	environment.systemPackages = with pkgs; [
		slack
	];
}
