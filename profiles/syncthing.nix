{
	user,
	pkgs,
	constants,
	...
}: let
	isDarwin = pkgs.stdenv.isDarwin;
	homeDir =
		if isDarwin
		then "/Users/${user}"
		else "/home/${user}";
	group =
		if isDarwin
		then "staff"
		else "users";
	deviceIds = constants.syncthingDeviceIds;
in {
	services.syncthing = {
		enable = true;
		openDefaultPorts = !isDarwin;
		dataDir = "${homeDir}/.local/share/syncthing";
		configDir = "${homeDir}/.config/syncthing";
		user = user;
		inherit group;
		guiAddress = "0.0.0.0:8384";
		overrideFolders = true;
		overrideDevices = true;

		settings = {
			devices = {
				tahani = {
					id = deviceIds.tahani;
					addresses = ["tcp://tahani:22000"];
				};
				jason = {
					id = deviceIds.jason;
					addresses = ["tcp://jason:22000"];
				};
				chidi = {
					id = deviceIds.chidi;
					addresses = ["tcp://chidi:22000"];
				};
			};

			folders = {
				nixos-config = {
					path = "${homeDir}/nixos-config";
					devices = ["tahani" "jason" "chidi"];
				};
			};

			options.globalAnnounceEnabled = false;
		};
	};
}
