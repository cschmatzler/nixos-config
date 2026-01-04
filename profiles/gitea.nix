{
	lib,
	pkgs,
	config,
	...
}: {
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
		environmentFile = "/run/secrets/gitea-litestream";
		settings = {
			dbs = [
				{
					path = "/var/lib/gitea/data/gitea.db";
					replicas = [
						{
							type = "s3";
							bucket = "michael-gitea-litestream";
							path = "gitea";
							endpoint = "s3.eu-central-003.backblazeb2.com";
						}
					];
				}
			];
		};
	};

	systemd.services.litestream = {
		serviceConfig = {
			User = lib.mkForce "gitea";
			Group = lib.mkForce "gitea";
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
		repository = "s3:s3.eu-central-003.backblazeb2.com/michael-gitea-repositories";
		paths = ["/var/lib/gitea"];
		exclude = [
			"/var/lib/gitea/log"
			"/var/lib/gitea/data/gitea.db"
			"/var/lib/gitea/data/gitea.db-shm"
			"/var/lib/gitea/data/gitea.db-wal"
		];
		passwordFile = "/run/secrets/restic-gitea-password";
		environmentFile = "/run/secrets/restic-gitea-env";
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
			User = lib.mkForce "gitea";
			Group = lib.mkForce "gitea";
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
			EnvironmentFile = config.sops.secrets.restic-gitea-env.path;
		};
		script = ''
			export RESTIC_PASSWORD=$(cat ${config.sops.secrets.restic-gitea-password.path})
			restic -r s3:s3.eu-central-003.backblazeb2.com/gitea-restic snapshots &>/dev/null || \
				restic -r s3:s3.eu-central-003.backblazeb2.com/gitea-restic init
		'';
	};
}
