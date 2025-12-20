{...}: {
	my.pgbackrest = {
		enable = true;
		secretFile = "/run/secrets/mindy-pgbackrest";
		s3.bucket = "mindy-pgbackrest";
	};
}
