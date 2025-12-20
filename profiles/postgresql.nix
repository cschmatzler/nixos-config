{pkgs, ...}: {
	services.postgresql = {
		enable = true;
		package = pkgs.postgresql_17;

		settings = {
			wal_level = "replica";
			archive_mode = "on";
			archive_command = "${pkgs.pgbackrest}/bin/pgbackrest --stanza=main archive-push %p";
			max_wal_senders = 3;
			max_connections = 100;
			shared_buffers = "256MB";
			log_connections = true;
			log_disconnections = true;
		};

		authentication =
			pkgs.lib.mkOverride 10 ''
				local   all       all                         peer
				host    all       all         127.0.0.1/32    scram-sha-256
				host    all       all         ::1/128         scram-sha-256
				host    all       all         100.64.0.0/10   scram-sha-256
			'';
	};

	networking.firewall.interfaces."tailscale0".allowedTCPPorts = [5432];
}
