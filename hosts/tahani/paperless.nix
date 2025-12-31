{config, ...}: {
	services.caddy = {
		enable = true;
		globalConfig = ''
			admin off
		'';
		virtualHosts."docs.manticore-hippocampus.ts.net" = {
			extraConfig = ''
				tls {
					get_certificate tailscale
				}
				reverse_proxy localhost:${toString config.services.paperless.port}
			'';
		};
		virtualHosts."docs-ai.manticore-hippocampus.ts.net" = {
			extraConfig = ''
				tls {
					get_certificate tailscale
				}
				reverse_proxy localhost:3000
			'';
		};
	};

	virtualisation.oci-containers = {
		backend = "docker";
		containers.paperless-ai = {
			image = "clusterzx/paperless-ai:latest";
			autoStart = true;
			volumes = [
				"paperless-ai-data:/app/data"
			];
			environment = {
				PUID = "1000";
				PGID = "1000";
				PAPERLESS_AI_PORT = "3000";
				# Initial setup wizard will configure the rest
				PAPERLESS_AI_INITIAL_SETUP = "yes";
				# Paperless-ngx API URL accessible from container (using host network)
				PAPERLESS_API_URL = "http://127.0.0.1:${toString config.services.paperless.port}/api";
			};
			extraOptions = [
				"--network=host"
			];
		};
	};

	services.redis.servers.paperless = {
		enable = true;
		port = 6379;
		bind = "127.0.0.1";
		settings = {
			maxmemory = "256mb";
			maxmemory-policy = "allkeys-lru";
		};
	};

	services.paperless = {
		enable = true;
		address = "0.0.0.0";
		passwordFile = config.sops.secrets.tahani-paperless-password.path;
		settings = {
			PAPERLESS_DBENGINE = "sqlite";
			PAPERLESS_REDIS = "redis://127.0.0.1:6379";
			PAPERLESS_CONSUMER_IGNORE_PATTERN = [
				".DS_STORE/*"
				"desktop.ini"
			];
			PAPERLESS_OCR_LANGUAGE = "deu+eng";
			PAPERLESS_CSRF_TRUSTED_ORIGINS = "https://docs.manticore-hippocampus.ts.net";
		};
	};
}
