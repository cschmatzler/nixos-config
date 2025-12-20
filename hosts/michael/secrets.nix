{...}: {
	sops.secrets.litestream = {
		sopsFile = ../../secrets/michael-litestream;
		format = "binary";
	};
}
