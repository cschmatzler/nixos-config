{user, ...}: {
	services.syncthing.settings.folders = {
		"Projects/Personal" = {
			path = "/Users/${user}/Projects/Personal";
			devices = ["tahani" "jason"];
		};
	};
}
