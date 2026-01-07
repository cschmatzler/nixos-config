{user, ...}: {
	sops.secrets = {
		derek-icloud-password = {
			sopsFile = ../../secrets/derek-icloud-password;
			format = "binary";
			owner = user;
		};
	};
}
