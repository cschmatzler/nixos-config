{...}: {
	sops.secrets = {
		tahani-paperless-password = {
			sopsFile = ../../secrets/tahani-paperless-password;
			format = "binary";
		};
	};
}
