{
  user,
  pkgs,
  lib,
  ...
}: let
  isDarwin = pkgs.stdenv.isDarwin;
  isLinux = pkgs.stdenv.isLinux;
  homeDir = if isDarwin then "/Users/${user}" else "/home/${user}";
in {
  services.syncthing = {
    enable = true;
    openDefaultPorts = isLinux;
    dataDir = "${homeDir}/.local/share/syncthing";
    configDir = "${homeDir}/.config/syncthing";
    user = "${user}";
    group = if isDarwin then "staff" else "users";
    guiAddress = "0.0.0.0:8384";
    overrideFolders = true;
    overrideDevices = true;

    settings = {
      devices = {
        "tahani" = {id = "6B7OZZF-TEAMUGO-FBOELXP-Z4OY7EU-5ZHLB5T-V6Z3UDB-Q2DYR43-QBYW6QM";};
        "jason" = {id = "42II2VO-QYPJG26-ZS3MB2I-AOPVZ67-JJNSE76-U54CO5Y-634A5OG-ECU4YQA";};
      };
      folders = {
        "Projects" = {
          path = "${homeDir}/Projects";
          devices = ["tahani" "jason"];
        };
      };
      options.globalAnnounceEnabled = false;
    };
  };
}
