{pkgs}: let
	wallpaper =
		pkgs.fetchurl {
			url = "https://misc-assets.raycast.com/wallpapers/bright-rain.png";
			sha256 = "sha256-wQT4I2X3gS6QFsEb7MdRsn4oX7FNkflukXPGMFbJZ10=";
		};
in
	pkgs.writeShellScriptBin "set-wallpaper-script" ''
		set -e
		/usr/bin/osascript -e "tell application \"Finder\" to set desktop picture to POSIX file \"${wallpaper}\""
	''
