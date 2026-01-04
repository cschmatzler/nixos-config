{...}: {
	sops.secrets = {
		michael-gitea-litestream = {
			sopsFile = ../../secrets/michael-gitea-litestream;
			format = "binary";
			owner = "gitea";
			group = "gitea";
		};
		michael-gitea-restic-password = {
			sopsFile = ../../secrets/michael-gitea-restic-password;
			format = "binary";
			owner = "gitea";
			group = "gitea";
		};
		michael-gitea-restic-env = {
			sopsFile = ../../secrets/michael-gitea-restic-env;
			format = "binary";
			owner = "gitea";
			group = "gitea";
		};
	};
}
