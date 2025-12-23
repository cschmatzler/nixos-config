{
	user,
	hostname,
	...
}: let
	secrets = import ../../lib/secrets.nix;
in {
	sops.age.keyFile = "/Users/${user}/.config/sops/age/keys.txt";
	sops.age.sshKeyPaths = [];
	sops.gnupg.sshKeyPaths = [];

	sops.secrets = secrets.mkSyncthingSecrets {
		inherit hostname user;
		isDarwin = true;
	};
}
