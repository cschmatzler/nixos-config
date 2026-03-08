{inputs, ...}: {
	# Import sops-nix modules into den.default per-class
	den.default.nixos.imports = [inputs.sops-nix.nixosModules.sops];
	den.default.darwin.imports = [inputs.sops-nix.darwinModules.sops];

	# Configure NixOS SOPS defaults
	den.default.nixos.sops.age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];

	# Configure Darwin SOPS defaults
	den.default.darwin = {
		sops.age.keyFile = "/Users/cschmatzler/.config/sops/age/keys.txt";
		sops.age.sshKeyPaths = [];
		sops.gnupg.sshKeyPaths = [];
	};

	# Encryption/secrets tools
	den.aspects.secrets.homeManager = {pkgs, ...}: {
		home.packages = with pkgs; [
			age
			gnupg
			sops
		];
	};
}
