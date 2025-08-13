{
  user,
  pkgs,
  ...
}: {
  services.syncthing = {
    enable = true;
    openDefaultPorts = pkgs.stdenv.isLinux;
    dataDir =
      if pkgs.stdenv.isDarwin
      then "/Users/${user}/.local/share/syncthing"
      else "/home/${user}/.local/share/syncthing";
    configDir =
      if pkgs.stdenv.isDarwin
      then "/Users/${user}/.config/syncthing"
      else "/home/${user}/.config/syncthing";
    user = "${user}";
    group =
      if pkgs.stdenv.isDarwin
      then "staff"
      else "users";
    guiAddress = "0.0.0.0:8384";
    overrideFolders = true;
    overrideDevices = true;

    settings = {
      devices = {
        "jason" = {id = "42II2VO-QYPJG26-ZS3MB2I-AOPVZ67-JJNSE76-U54CO5Y-634A5OG-ECU4YQA";};
        "tahani" = {id = "6B7OZZF-TEAMUGO-FBOELXP-Z4OY7EU-5ZHLB5T-V6Z3UDB-Q2DYR43-QBYW6QM";};
      };
      folders = {
        "Projects" = {
          path =
            if pkgs.stdenv.isDarwin
            then "/Users/${user}/Projects"
            else "/home/${user}/Projects";
          devices = [];
        };
      };
      options.globalAnnounceEnabled = false;
    };
  };
}
