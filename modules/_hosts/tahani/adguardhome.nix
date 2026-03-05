{
	services.adguardhome = {
		enable = true;
		host = "0.0.0.0";
		port = 10000;
		settings = {
			dhcp = {
				enabled = false;
			};
			dns = {
				upstream_dns = [
					"1.1.1.1"
					"1.0.0.1"
				];
			};
			filtering = {
				protection_enabled = true;
				filtering_enabled = true;
				safe_search = {
					enabled = false;
				};
				safebrowsing_enabled = true;
				blocked_response_ttl = 10;
				filters_update_interval = 24;
				blocked_services = {
					ids = [
						"reddit"
						"twitter"
					];
				};
			};
			filters = [
				{
					enabled = true;
					url = "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/pro.txt";
					name = "HaGeZi Multi PRO";
					id = 1;
				}
				{
					enabled = true;
					url = "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/tif.txt";
					name = "HaGeZi Threat Intelligence Feeds";
					id = 2;
				}
				{
					enabled = true;
					url = "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/gambling.txt";
					name = "HaGeZi Gambling";
					id = 3;
				}
				{
					enabled = true;
					url = "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/nsfw.txt";
					name = "HaGeZi NSFW";
					id = 4;
				}
			];
		};
	};
}
