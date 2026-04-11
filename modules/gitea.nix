{lib, ...}: let
	secretLib = import ./_lib/secrets.nix {inherit lib;};
	serviceUser = "gitea";
	stateDir = "/var/lib/${serviceUser}";
	dataDir = "${stateDir}/data";
	dbPath = "${dataDir}/gitea.db";
	domain = "git.schmatzler.com";
	rootUrl = "https://${domain}/";
	httpAddr = "127.0.0.1";
	httpPort = 3000;
	redisHost = "127.0.0.1";
	redisPort = 6380;
	redisUrl = db: "redis://${redisHost}:${toString redisPort}/${toString db}?pool_size=100&idle_timeout=180s";
	backblazeEndpoint = "s3.eu-central-003.backblazeb2.com";
	litestreamBucket = "michael-gitea-litestream";
	resticRepository = "s3:${backblazeEndpoint}/michael-gitea-repositories";
in {
	den.aspects.gitea.nixos = {
		config,
		lib,
		pkgs,
		...
	}: {
		sops.secrets = {
			michael-gitea-litestream =
				secretLib.mkServiceBinarySecret {
					name = "michael-gitea-litestream";
					inherit serviceUser;
					sopsFile = ../secrets/michael-gitea-litestream;
				};
			michael-gitea-restic-password =
				secretLib.mkServiceBinarySecret {
					name = "michael-gitea-restic-password";
					inherit serviceUser;
					sopsFile = ../secrets/michael-gitea-restic-password;
				};
			michael-gitea-restic-env =
				secretLib.mkServiceBinarySecret {
					name = "michael-gitea-restic-env";
					inherit serviceUser;
					sopsFile = ../secrets/michael-gitea-restic-env;
				};
		};

		networking.firewall.allowedTCPPorts = [80 443];

		services.redis.servers.gitea = {
			enable = true;
			port = redisPort;
			bind = redisHost;
			settings = {
				maxmemory = "64mb";
				maxmemory-policy = "allkeys-lru";
			};
		};

		services.gitea = {
			enable = true;
			database = {
				type = "sqlite3";
				path = dbPath;
			};
			settings = {
				server = {
					ROOT_URL = rootUrl;
					DOMAIN = domain;
					HTTP_ADDR = httpAddr;
					HTTP_PORT = httpPort;
					LANDING_PAGE = "explore";
				};
				service.DISABLE_REGISTRATION = true;
				security.INSTALL_LOCK = true;
				cache = {
					ADAPTER = "redis";
					HOST = redisUrl 0;
					ITEM_TTL = "16h";
				};
				"cache.last_commit" = {
					ITEM_TTL = "8760h";
					COMMITS_COUNT = 100;
				};
				session = {
					PROVIDER = "redis";
					PROVIDER_CONFIG = redisUrl 1;
					COOKIE_SECURE = true;
					SAME_SITE = "strict";
				};
				api.ENABLE_SWAGGER = false;
			};
		};

		services.litestream = {
			enable = true;
			environmentFile = config.sops.secrets.michael-gitea-litestream.path;
			settings.dbs = [
				{
					path = dbPath;
					replicas = [
						{
							type = "s3";
							bucket = litestreamBucket;
							path = serviceUser;
							endpoint = backblazeEndpoint;
						}
					];
				}
			];
		};

		systemd.services.litestream.serviceConfig = {
			User = lib.mkForce serviceUser;
			Group = lib.mkForce serviceUser;
		};

		services.caddy = {
			enable = true;
			virtualHosts.${domain}.extraConfig = ''
				header {
					Strict-Transport-Security "max-age=31536000; includeSubDomains"
					X-Content-Type-Options "nosniff"
					X-Frame-Options "DENY"
					Referrer-Policy "strict-origin-when-cross-origin"
				}
				reverse_proxy localhost:${toString httpPort}
			'';
		};

		services.restic.backups.gitea = {
			repository = resticRepository;
			paths = [stateDir];
			exclude = [
				"${stateDir}/log"
				dbPath
				"${dbPath}-shm"
				"${dbPath}-wal"
			];
			passwordFile = config.sops.secrets.michael-gitea-restic-password.path;
			environmentFile = config.sops.secrets.michael-gitea-restic-env.path;
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
				User = lib.mkForce serviceUser;
				Group = lib.mkForce serviceUser;
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
				User = serviceUser;
				Group = serviceUser;
				RemainAfterExit = true;
				EnvironmentFile = config.sops.secrets.michael-gitea-restic-env.path;
			};
			script = ''
				export RESTIC_PASSWORD=$(cat ${config.sops.secrets.michael-gitea-restic-password.path})
				restic -r ${resticRepository} snapshots &>/dev/null || \
					restic -r ${resticRepository} init
			'';
		};
	};
}
