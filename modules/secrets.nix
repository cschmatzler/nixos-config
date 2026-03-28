{inputs, ...}: let
	local = import ./_lib/local.nix;
in {
	# Import sops-nix modules into den.default per-class
	den.default.nixos.imports = [inputs.sops-nix.nixosModules.sops];
	den.default.darwin.imports = [inputs.sops-nix.darwinModules.sops];

	# Configure NixOS SOPS defaults
	den.default.nixos.sops.age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];

	# Configure Darwin SOPS defaults
	den.default.darwin = {
		sops.age.keyFile = "${local.mkHome local.hosts.chidi.system}/.config/sops/age/keys.txt";
		sops.age.sshKeyPaths = [];
		sops.gnupg.sshKeyPaths = [];
	};

	# Encryption/secrets tools
	den.aspects.secrets.homeManager = {pkgs, ...}: {
		home.packages = with pkgs; [
			age
			gnupg
			sops
			ssh-to-age
		];
		home.sessionVariables.SOPS_AGE_SSH_PRIVATE_KEY_FILE = "~/.ssh/id_ed25519";
	};
}
