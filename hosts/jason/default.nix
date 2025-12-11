{
	inputs,
	user,
	...
}: {
	imports = [
		../../modules/core.nix
		../../modules/darwin.nix
		../../modules/darwin-syncthing.nix
		../../modules/darwin-system.nix
		../../modules/dock.nix
		../../modules/homebrew.nix
		../../modules/syncthing.nix
		../../modules/tailscale.nix
		inputs.sops-nix.darwinModules.sops
	];

	networking.hostName = "jason";
	networking.computerName = "Jason";

	services.syncthing.settings.folders = {
		"Projects/Personal" = {
			path = "/Users/${user}/Projects/Personal";
			devices = ["tahani" "jason"];
		};
	};

	sops.age.keyFile = "/Users/${user}/.config/sops/age/keys.txt";

	sops.secrets = {
		jason-syncthing-cert = {
			sopsFile = ../../secrets/jason-syncthing-cert;
			format = "binary";
			owner = user;
			path = "/Users/${user}/.config/syncthing/cert.pem";
		};
		jason-syncthing-key = {
			sopsFile = ../../secrets/jason-syncthing-key;
			format = "binary";
			owner = user;
			path = "/Users/${user}/.config/syncthing/key.pem";
		};
	};

	home-manager.users.${user} = {
		pkgs,
		lib,
		constants,
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
		programs.git.settings.user.email = "christoph@schmatzler.com";
	};
}
