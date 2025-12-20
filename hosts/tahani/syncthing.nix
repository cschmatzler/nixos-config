{user, ...}: {
	services.syncthing.settings.folders = {
		"Projects/Personal" = {
			path = "/home/${user}/Projects/Personal";
			devices = ["tahani" "jason"];
		};
		"Projects/Work" = {
			path = "/home/${user}/Projects/Work";
			devices = ["tahani" "chidi"];
		};
	};
}
