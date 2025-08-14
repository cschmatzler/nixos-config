{
  user,
  pkgs,
  ...
}: let
  isDarwin = pkgs.stdenv.isDarwin;

  platformConfig =
    if isDarwin
    then {
      homeDir = "/Users/${user}";
      group = "staff";
    }
    else {
      homeDir = "/home/${user}";
      group = "users";
    };
in {
  services.syncthing = {
    enable = true;
    openDefaultPorts = !isDarwin;
    dataDir = "${platformConfig.homeDir}/.local/share/syncthing";
    configDir = "${platformConfig.homeDir}/.config/syncthing";
    user = "${user}";
    group = platformConfig.group;
    guiAddress = "0.0.0.0:8384";
    overrideFolders = true;
    overrideDevices = true;

    settings = {
      devices = {
        "tahani" = {id = "6B7OZZF-TEAMUGO-FBOELXP-Z4OY7EU-5ZHLB5T-V6Z3UDB-Q2DYR43-QBYW6QM";};
        "jason" = {id = "42II2VO-QYPJG26-ZS3MB2I-AOPVZ67-JJNSE76-U54CO5Y-634A5OG-ECU4YQA";};
        "chidi" = {id = "N7W6SUT-QO6J4BE-T3Y65SM-OFGYGNV-TGYBJPX-JVN4Z72-AENZ247-KWXOQA6";};
      };
      folders = {
        "Projects" = {
          path = "${platformConfig.homeDir}/Projects";
          devices = ["tahani" "jason" "chidi"];
        };
      };
      options.globalAnnounceEnabled = false;
    };
  };
}
