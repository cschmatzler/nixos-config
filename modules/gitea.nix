{
	config,
	lib,
	pkgs,
	...
}:
with lib; let
	cfg = config.my.gitea;
in {
	options.my.gitea = {
		enable = mkEnableOption "Gitea git hosting service";

		litestream = {
			bucket = mkOption {
				type = types.str;
				description = "S3 bucket name for Litestream database replication";
			};

			secretFile = mkOption {
				type = types.path;
				description = "Path to the environment file containing S3 credentials for Litestream";
			};
		};

		restic = {
			bucket = mkOption {
				type = types.str;
				description = "S3 bucket name for Restic repository backups";
			};

			passwordFile = mkOption {
				type = types.path;
				description = "Path to the file containing the Restic repository password";
			};

			environmentFile = mkOption {
				type = types.path;
				description = "Path to the environment file containing S3 credentials for Restic";
			};
		};

		s3 = {
			endpoint = mkOption {
				type = types.str;
				default = "s3.eu-central-003.backblazeb2.com";
				description = "S3 endpoint URL";
			};
		};
	};

	config = mkIf cfg.enable {
		networking.firewall.allowedTCPPorts = [80 443];

		services.redis.servers.gitea = {
			enable = true;
			port = 6380;
			bind = "127.0.0.1";
			settings = {
				maxmemory = "64mb";
				maxmemory-policy = "allkeys-lru";
			};
		};

		services.gitea = {
			enable = true;
			database = {
				type = "sqlite3";
				path = "/var/lib/gitea/data/gitea.db";
			};
			settings = {
				server = {
					ROOT_URL = "https://git.schmatzler.com/";
					DOMAIN = "git.schmatzler.com";
					HTTP_ADDR = "127.0.0.1";
					HTTP_PORT = 3000;
					LANDING_PAGE = "explore";
				};
				service.DISABLE_REGISTRATION = true;
				security.INSTALL_LOCK = true;
				cache = {
					ADAPTER = "redis";
					HOST = "redis://127.0.0.1:6380/0?pool_size=100&idle_timeout=180s";
					ITEM_TTL = "16h";
				};
				"cache.last_commit" = {
					ITEM_TTL = "8760h";
					COMMITS_COUNT = 100;
				};
				session = {
					PROVIDER = "redis";
					PROVIDER_CONFIG = "redis://127.0.0.1:6380/1?pool_size=100&idle_timeout=180s";
					COOKIE_SECURE = true;
					SAME_SITE = "strict";
				};
				api.ENABLE_SWAGGER = false;
			};
		};

		services.litestream = {
			enable = true;
			environmentFile = cfg.litestream.secretFile;
			settings = {
				dbs = [
					{
						path = "/var/lib/gitea/data/gitea.db";
						replicas = [
							{
								type = "s3";
								bucket = cfg.litestream.bucket;
								path = "gitea";
								endpoint = cfg.s3.endpoint;
							}
						];
					}
				];
			};
		};

		systemd.services.litestream = {
			serviceConfig = {
				User = mkForce "gitea";
				Group = mkForce "gitea";
			};
		};

		services.caddy = {
			enable = true;
			virtualHosts."git.schmatzler.com".extraConfig = ''
				header {
					Strict-Transport-Security "max-age=31536000; includeSubDomains"
					X-Content-Type-Options "nosniff"
					X-Frame-Options "DENY"
					Referrer-Policy "strict-origin-when-cross-origin"
				}
				reverse_proxy localhost:3000
			'';
		};

		services.restic.backups.gitea = {
			repository = "s3:${cfg.s3.endpoint}/${cfg.restic.bucket}";
			paths = ["/var/lib/gitea"];
			exclude = [
				"/var/lib/gitea/log"
				"/var/lib/gitea/data/gitea.db"
				"/var/lib/gitea/data/gitea.db-shm"
				"/var/lib/gitea/data/gitea.db-wal"
			];
			passwordFile = cfg.restic.passwordFile;
			environmentFile = cfg.restic.environmentFile;
			pruneOpts = [
				"--keep-daily 7"
				"--keep-weekly 4"
				"--keep-monthly 6"
			];
			timerConfig = {
				OnCalendar = "daily";
				Persistent = true;
				RandomizedDelaySec = "1h";
			};
		};

		systemd.services.restic-backups-gitea = {
			wants = ["restic-init-gitea.service"];
			after = ["restic-init-gitea.service"];
			serviceConfig = {
				User = mkForce "gitea";
				Group = mkForce "gitea";
			};
		};

		systemd.services.restic-init-gitea = {
			description = "Initialize Restic repository for Gitea backups";
			wantedBy = ["multi-user.target"];
			after = ["network-online.target"];
			wants = ["network-online.target"];
			path = [pkgs.restic];
			serviceConfig = {
				Type = "oneshot";
				User = "gitea";
				Group = "gitea";
				RemainAfterExit = true;
				EnvironmentFile = cfg.restic.environmentFile;
			};
			script = ''
				export RESTIC_PASSWORD=$(cat ${cfg.restic.passwordFile})
				restic -r s3:${cfg.s3.endpoint}/${cfg.restic.bucket} snapshots &>/dev/null || \
					restic -r s3:${cfg.s3.endpoint}/${cfg.restic.bucket} init
			'';
		};
	};
}
