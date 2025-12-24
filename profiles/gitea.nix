{lib, ...}: {
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
		environmentFile = "/run/secrets/litestream";
		settings = {
			dbs = [
				{
					path = "/var/lib/gitea/data/gitea.db";
					replicas = [
						{
							type = "s3";
							bucket = "gitea-litestream";
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
}
