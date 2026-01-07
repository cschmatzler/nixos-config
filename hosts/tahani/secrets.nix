{user, ...}: {
	sops.secrets = {
		tahani-paperless-password = {
			sopsFile = ../../secrets/tahani-paperless-password;
			format = "binary";
		};
		tahani-icloud-password = {
			sopsFile = ../../secrets/tahani-icloud-password;
			format = "binary";
			owner = user;
		};
	};
}
