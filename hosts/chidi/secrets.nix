{user, ...}: {
	sops.age.keyFile = "/Users/${user}/.config/sops/age/keys.txt";

	sops.secrets = {
		chidi-syncthing-cert = {
			sopsFile = ../../secrets/chidi-syncthing-cert;
			format = "binary";
			owner = user;
			path = "/Users/${user}/.config/syncthing/cert.pem";
		};
		chidi-syncthing-key = {
			sopsFile = ../../secrets/chidi-syncthing-key;
			format = "binary";
			owner = user;
			path = "/Users/${user}/.config/syncthing/key.pem";
		};
	};
}
