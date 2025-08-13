{user, ...}: {
  services.syncthing = {
    enable = true;
    openDefaultPorts = true;
    dataDir = "/home/${user}/.local/share/syncthing";
    configDir = "/home/${user}/.config/syncthing";
    user = "${user}";
    group = "users";
    guiAddress = "0.0.0.0:8384";
    overrideFolders = true;
    overrideDevices = true;

    settings = {
      devices = {};
      folders = {
        "Projects" = {
          path = "/home/${user}/Projects";
          devices = [];
        };
      };
      options.globalAnnounceEnabled = false;
    };
  };
}
