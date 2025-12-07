{
  user,
  pkgs,
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
in {
  services.syncthing = {
    enable = true;
    openDefaultPorts = !isDarwin;
    dataDir = "${homeDir}/.local/share/syncthing";
    configDir = "${homeDir}/.config/syncthing";
    user = "${user}";
    group = group;
    guiAddress = "0.0.0.0:8384";
    overrideFolders = true;
    overrideDevices = true;

    settings = {
      devices = {
        "tahani" = {
          id = "6B7OZZF-TEAMUGO-FBOELXP-Z4OY7EU-5ZHLB5T-V6Z3UDB-Q2DYR43-QBYW6QM";
          addresses = ["tcp://tahani:22000"];
        };
        "jason" = {
          id = "42II2VO-QYPJG26-ZS3MB2I-AOPVZ67-JJNSE76-U54CO5Y-634A5OG-ECU4YQA";
          addresses = ["tcp://jason:22000"];
        };
        "chidi" = {
          id = "N7W6SUT-QO6J4BE-T3Y65SM-OFGYGNV-TGYBJPX-JVN4Z72-AENZ247-KWXOQA6";
          addresses = ["tcp://chidi:22000"];
        };
      };

      folders = {
        "nixos-config" = {
          path = "${homeDir}/nixos-config";
          devices = ["tahani" "jason" "chidi"];
        };
      };

      options.globalAnnounceEnabled = false;
    };
  };
}
