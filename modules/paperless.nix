{lib, ...}: let
	caddyLib = import ./_lib/caddy.nix;
	local = import ./_lib/local.nix;
	secretLib = import ./_lib/secrets.nix {inherit lib;};
	paperlessPrompts = ./_paperless;
in {
	den.aspects.paperless.nixos = {config, ...}: {
		sops.secrets = {
			tahani-paperless-password =
				secretLib.mkBinarySecret {
					name = "tahani-paperless-password";
					sopsFile = ../secrets/tahani-paperless-password;
				};
			tahani-paperless-gpt-env =
				secretLib.mkBinarySecret {
					name = "tahani-paperless-gpt-env";
					sopsFile = ../secrets/tahani-paperless-gpt-env;
				};
		};

		services.caddy = {
			enable = true;
			enableReload = false;
			globalConfig = ''
				admin off
			'';
			virtualHosts =
				caddyLib.mkTailscaleVHost {
					name = "docs";
					configText = "reverse_proxy localhost:${toString config.services.paperless.port}";
				}
				// caddyLib.mkTailscaleVHost {
					name = "docs-ai";
					configText = "reverse_proxy localhost:8081";
				};
		};

		virtualisation.oci-containers = {
			backend = "docker";
			containers.paperless-gpt = {
				image = "icereed/paperless-gpt:latest";
				autoStart = true;
				ports = [
					"127.0.0.1:8081:8080"
				];
				volumes = [
					"paperless-gpt-data:/app/data"
					"paperless-gpt-prompts:/app/prompts"
					"${paperlessPrompts}/tag_prompt.tmpl:/app/prompts/tag_prompt.tmpl:ro"
					"${paperlessPrompts}/title_prompt.tmpl:/app/prompts/title_prompt.tmpl:ro"
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
				PAPERLESS_CSRF_TRUSTED_ORIGINS = "https://${local.tailscaleHost "docs"}";
			};
		};
	};
}
