{config, ...}: {
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
		};
	};
}
