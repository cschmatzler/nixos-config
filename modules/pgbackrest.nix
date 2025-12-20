{
	config,
	lib,
	pkgs,
	...
}:
with lib; let
	cfg = config.services.pgbackrest;
in {
	options.services.pgbackrest = {
		enable = mkEnableOption "pgBackRest PostgreSQL backup";

		stanza = mkOption {
			type = types.str;
			default = "main";
			description = "Name of the pgBackRest stanza";
		};

		secretFile = mkOption {
			type = types.path;
			description = "Path to the environment file containing S3 credentials and cipher passphrase";
		};

		s3 = {
			endpoint = mkOption {
				type = types.str;
				default = "s3.eu-central-003.backblazeb2.com";
				description = "S3 endpoint URL";
			};

			bucket = mkOption {
				type = types.str;
				description = "S3 bucket name";
			};

			region = mkOption {
				type = types.str;
				default = "eu-central-003";
				description = "S3 region";
			};

			path = mkOption {
				type = types.str;
				default = "/backups";
				description = "Path within the S3 bucket";
			};
		};

		retention = {
			full = mkOption {
				type = types.int;
				default = 7;
				description = "Number of full backups to retain";
			};

			diff = mkOption {
				type = types.int;
				default = 7;
				description = "Number of differential backups to retain";
			};
		};

		compression = {
			type = mkOption {
				type = types.str;
				default = "zst";
				description = "Compression algorithm (none, gz, lz4, zst)";
			};

			level = mkOption {
				type = types.int;
				default = 3;
				description = "Compression level";
			};
		};

		processMax = mkOption {
			type = types.int;
			default = 2;
			description = "Maximum number of processes for parallel operations";
		};

		schedule = {
			full = mkOption {
				type = types.str;
				default = "daily";
				description = "OnCalendar expression for full backups";
			};

			diff = mkOption {
				type = types.str;
				default = "hourly";
				description = "OnCalendar expression for differential backups";
			};
		};
	};

	config = mkIf cfg.enable (let
		archivePushScript = pkgs.writeShellScript "pgbackrest-archive-push" ''
			set -a
			source ${cfg.secretFile}
			set +a
			exec ${pkgs.pgbackrest}/bin/pgbackrest --stanza=${cfg.stanza} archive-push "$1"
		'';
	in {
		environment.systemPackages = [
			pkgs.pgbackrest
			(pkgs.writeShellScriptBin "pgbackrest-wrapper" ''
				set -a
				source ${cfg.secretFile}
				set +a
				exec ${pkgs.pgbackrest}/bin/pgbackrest "$@"
			'')
		];

		services.postgresql.settings = {
			archive_mode = "on";
			archive_command = "${archivePushScript} %p";
		};

		environment.etc."pgbackrest/pgbackrest.conf".text = ''
			[global]
			repo1-type=s3
			repo1-s3-endpoint=${cfg.s3.endpoint}
			repo1-s3-bucket=${cfg.s3.bucket}
			repo1-s3-region=${cfg.s3.region}
			repo1-path=${cfg.s3.path}
			repo1-retention-full=${toString cfg.retention.full}
			repo1-retention-diff=${toString cfg.retention.diff}
			repo1-cipher-type=aes-256-cbc
			compress-type=${cfg.compression.type}
			compress-level=${toString cfg.compression.level}
			process-max=${toString cfg.processMax}
			log-level-console=info
			log-level-file=detail
			log-path=/var/log/pgbackrest
			spool-path=/var/spool/pgbackrest

			[${cfg.stanza}]
			pg1-path=/var/lib/postgresql/${config.services.postgresql.package.psqlSchema}
			pg1-user=postgres
		'';

		systemd.services.pgbackrest-stanza-create = {
			description = "pgBackRest Stanza Create";
			after = ["postgresql.service"];
			requires = ["postgresql.service"];
			path = [pkgs.pgbackrest];
			serviceConfig = {
				Type = "oneshot";
				User = "postgres";
				EnvironmentFile = cfg.secretFile;
				RemainAfterExit = true;
			};
			script = ''
				pgbackrest --stanza=${cfg.stanza} stanza-create || true
			'';
		};

		systemd.services.pgbackrest-backup = {
			description = "pgBackRest Full Backup";
			after = ["postgresql.service" "pgbackrest-stanza-create.service"];
			requires = ["postgresql.service"];
			wants = ["pgbackrest-stanza-create.service"];
			path = [pkgs.pgbackrest];
			serviceConfig = {
				Type = "oneshot";
				User = "postgres";
				EnvironmentFile = cfg.secretFile;
			};
			script = ''
				pgbackrest --stanza=${cfg.stanza} backup --type=full
			'';
		};

		systemd.timers.pgbackrest-backup = {
			wantedBy = ["timers.target"];
			timerConfig = {
				OnCalendar = cfg.schedule.full;
				Persistent = true;
				RandomizedDelaySec = "1h";
			};
		};

		systemd.services.pgbackrest-backup-diff = {
			description = "pgBackRest Differential Backup";
			after = ["postgresql.service" "pgbackrest-stanza-create.service"];
			requires = ["postgresql.service"];
			wants = ["pgbackrest-stanza-create.service"];
			path = [pkgs.pgbackrest];
			serviceConfig = {
				Type = "oneshot";
				User = "postgres";
				EnvironmentFile = cfg.secretFile;
			};
			script = ''
				pgbackrest --stanza=${cfg.stanza} backup --type=diff
			'';
		};

		systemd.timers.pgbackrest-backup-diff = {
			wantedBy = ["timers.target"];
			timerConfig = {
				OnCalendar = cfg.schedule.diff;
				Persistent = true;
				RandomizedDelaySec = "5m";
			};
		};

		systemd.tmpfiles.rules = [
			"d /var/lib/pgbackrest 0750 postgres postgres -"
			"d /var/log/pgbackrest 0750 postgres postgres -"
			"d /var/spool/pgbackrest 0750 postgres postgres -"
		];
	});
}
