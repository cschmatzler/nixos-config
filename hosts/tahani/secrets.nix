{user, ...}: {
	sops.secrets = {
		tahani-paperless-password = {
			sopsFile = ../../secrets/tahani-paperless-password;
			format = "binary";
		};
		tahani-email-password = {
			sopsFile = ../../secrets/tahani-email-password;
			format = "binary";
			owner = user;
		};
	};
}
