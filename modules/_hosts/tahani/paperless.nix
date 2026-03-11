{config, ...}: {
	services.caddy = {
		enable = true;
		enableReload = false;
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
			image = "clusterzx/paperless-ai:v3.0.9";
			autoStart = true;
			ports = [
				"127.0.0.1:3000:3000"
			];
			volumes = [
				"paperless-ai-data:/app/data"
			];
			environment = {
				PUID = "1000";
				PGID = "1000";
				PAPERLESS_AI_PORT = "3000";
				# Initial setup wizard will configure the rest
				PAPERLESS_AI_INITIAL_SETUP = "yes";
				PAPERLESS_API_URL = "http://host.docker.internal:${toString config.services.paperless.port}/api";
			};
			extraOptions = [
				"--add-host=host.docker.internal:host-gateway"
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
		address = "127.0.0.1";
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
