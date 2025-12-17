{pkgs, ...}: {
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

	users.users.litestream.extraGroups = ["gitea"];

	systemd.services.gitea.serviceConfig.ExecStartPost =
		"+"
		+ pkgs.writeShellScript "grant-gitea-permissions" ''
			timeout=10

			while [ ! -f /var/lib/gitea/data/gitea.db ];
			do
				if [ "$timeout" == 0 ]; then
					echo "ERROR: Timeout while waiting for /var/lib/gitea/data/gitea.db."
					exit 1
				fi

				sleep 1

				((timeout--))
			done

			find /var/lib/gitea -type d -exec chmod -v 775 {} \;
			find /var/lib/gitea -type f -exec chmod -v 660 {} \;
		'';

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
