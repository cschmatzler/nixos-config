{
	mkSyncthingSecrets = {
		hostname,
		user,
		isDarwin,
	}: let
		homeDir =
			if isDarwin
			then "/Users/${user}"
			else "/home/${user}";
	in {
		"${hostname}-syncthing-cert" = {
			sopsFile = ../secrets/${hostname}-syncthing-cert;
			format = "binary";
			owner = user;
			path = "${homeDir}/.config/syncthing/cert.pem";
		};
		"${hostname}-syncthing-key" = {
			sopsFile = ../secrets/${hostname}-syncthing-key;
			format = "binary";
			owner = user;
			path = "${homeDir}/.config/syncthing/key.pem";
		};
	};
}
