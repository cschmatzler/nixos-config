{
	inputs,
	pkgs,
	user,
	constants,
	...
}: {
	imports = [
		../../modules/syncthing.nix
		../../profiles/core.nix
		../../profiles/darwin.nix
		../../profiles/dock.nix
		../../profiles/homebrew.nix
		../../profiles/syncthing.nix
		../../profiles/tailscale.nix
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
			../../profiles/atuin.nix
			../../profiles/bash.nix
			../../profiles/bat.nix
			../../profiles/direnv.nix
			../../profiles/eza.nix
			../../profiles/fish.nix
			../../profiles/fzf.nix
			../../profiles/ghostty.nix
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
		fonts.fontconfig.enable = true;
		programs.git.settings.user.email = "christoph@tuist.dev";
	};

	environment.systemPackages = with pkgs; [
		slack
	];
}
