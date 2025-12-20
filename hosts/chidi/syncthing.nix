{user, ...}: {
	services.syncthing.settings.folders = {
		"Projects/Work" = {
			path = "/Users/${user}/Projects/Work";
			devices = ["tahani" "chidi"];
		};
	};
}
