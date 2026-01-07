{...}: {
	programs.vdirsyncer = {
		enable = true;
	};

	programs.khal = {
		enable = true;
		locale = {
			timeformat = "%H:%M";
			dateformat = "%d/%m/%Y";
			longdateformat = "%d/%m/%Y";
			datetimeformat = "%d/%m/%Y %H:%M";
			longdatetimeformat = "%d/%m/%Y %H:%M";
		};
	};

	accounts.calendar = {
		basePath = ".local/share/calendars";

		accounts.icloud = {
			primary = true;
			primaryCollection = "home";

			remote = {
				type = "caldav";
				url = "https://caldav.icloud.com/";
				userName = "christoph@schmatzler.com";
				passwordCommand = ["cat" "/run/secrets/tahani-icloud-password"];
			};

			local = {
				type = "filesystem";
				fileExt = ".ics";
			};

			vdirsyncer = {
				enable = true;
				collections = ["from a" "from b"];
				metadata = ["color" "displayname"];
			};

			khal = {
				enable = true;
				type = "discover";
			};
		};
	};

	services.vdirsyncer = {
		enable = true;
		frequency = "*:0/15";
	};
}
