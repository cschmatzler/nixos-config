{...}: {
	sops.secrets.litestream = {
		sopsFile = ../../secrets/michael-litestream;
		format = "binary";
	};

	sops.secrets.restic-gitea-password = {
		sopsFile = ../../secrets/michael-restic-gitea-password;
		format = "binary";
		owner = "gitea";
		group = "gitea";
	};

	sops.secrets.restic-gitea-env = {
		sopsFile = ../../secrets/michael-restic-gitea-env;
		format = "binary";
		owner = "gitea";
		group = "gitea";
	};
}
