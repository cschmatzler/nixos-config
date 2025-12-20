{user, ...}: {
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
}
