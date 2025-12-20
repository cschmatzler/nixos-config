{
	inputs,
	user,
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

	networking.hostName = "jason";
	networking.computerName = "Jason";

	services.syncthing.settings.folders = {
		"Projects/Personal" = {
			path = "/Users/${user}/Projects/Personal";
			devices = ["tahani" "jason"];
		};
	};

	sops.age.keyFile = "/Users/${user}/.config/sops/age/keys.txt";
	sops.age.sshKeyPaths = [];
	sops.gnupg.sshKeyPaths = [];

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
		programs.git.settings.user.email = "christoph@schmatzler.com";
	};
}
