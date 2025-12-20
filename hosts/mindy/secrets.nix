{...}: {
	sops.secrets.mindy-pgbackrest = {
		sopsFile = ../../secrets/mindy-pgbackrest;
		format = "binary";
		owner = "postgres";
		group = "postgres";
	};
}
