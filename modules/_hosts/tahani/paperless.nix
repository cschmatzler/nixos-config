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
				reverse_proxy localhost:8080
			'';
		};
	};

	virtualisation.oci-containers = {
		backend = "docker";
		containers.paperless-gpt = {
			image = "icereed/paperless-gpt:latest";
			autoStart = true;
			ports = [
				"127.0.0.1:8080:8080"
			];
			volumes = [
				"paperless-gpt-data:/app/data"
				"paperless-gpt-prompts:/app/prompts"
				"${./paperless-gpt-prompts/tag_prompt.tmpl}:/app/prompts/tag_prompt.tmpl:ro"
				"${./paperless-gpt-prompts/title_prompt.tmpl}:/app/prompts/title_prompt.tmpl:ro"
			];
			environment = {
				PAPERLESS_BASE_URL = "http://host.docker.internal:${toString config.services.paperless.port}";
				LLM_PROVIDER = "openai";
				LLM_MODEL = "gpt-5.4";
				LLM_LANGUAGE = "German";
				VISION_LLM_PROVIDER = "openai";
				VISION_LLM_MODEL = "gpt-5.4";
				LOG_LEVEL = "info";
			};
			environmentFiles = [
				config.sops.secrets.tahani-paperless-gpt-env.path
			];
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
		address = "0.0.0.0";
		consumptionDir = "/var/lib/paperless/consume";
		passwordFile = config.sops.secrets.tahani-paperless-password.path;
		settings = {
			PAPERLESS_DBENGINE = "sqlite";
			PAPERLESS_REDIS = "redis://127.0.0.1:6379";
			PAPERLESS_CONSUMER_IGNORE_PATTERN = [
				".DS_STORE/*"
				"desktop.ini"
			];
			PAPERLESS_CONSUMER_POLLING = 30;
			PAPERLESS_CONSUMER_RECURSIVE = true;
			PAPERLESS_CONSUMER_SUBDIRS_AS_TAGS = true;
			PAPERLESS_OCR_LANGUAGE = "deu+eng";
			PAPERLESS_CSRF_TRUSTED_ORIGINS = "https://docs.manticore-hippocampus.ts.net";
		};
	};
}
