{user, ...}: {
	sops.secrets = {
		tahani-syncthing-cert = {
			sopsFile = ../../secrets/tahani-syncthing-cert;
			format = "binary";
			owner = user;
			path = "/home/${user}/.config/syncthing/cert.pem";
		};
		tahani-syncthing-key = {
			sopsFile = ../../secrets/tahani-syncthing-key;
			format = "binary";
			owner = user;
			path = "/home/${user}/.config/syncthing/key.pem";
		};
		tahani-paperless-password = {
			sopsFile = ../../secrets/tahani-paperless-password;
			format = "binary";
		};
	};
}
