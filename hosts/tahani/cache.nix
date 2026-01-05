{...}: {
	services.caddy.virtualHosts."cache.manticore-hippocampus.ts.net" = {
		extraConfig = ''
			tls {
				get_certificate tailscale
			}
			reverse_proxy localhost:32843
		'';
	};
}
