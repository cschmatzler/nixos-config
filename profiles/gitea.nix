{...}: {
	networking.firewall.allowedTCPPorts = [80 443];

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
			};
			service.DISABLE_REGISTRATION = true;
			security.INSTALL_LOCK = true;
			session = {
				COOKIE_SECURE = true;
				SAME_SITE = "strict";
			};
			api.ENABLE_SWAGGER = false;
			server.LANDING_PAGE = "explore";
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
			User = "gitea";
			Group = "gitea";
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
