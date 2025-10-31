{user, ...}: {
  imports = [
    ../../modules/darwin
  ];

  networking.hostName = "jason";
  networking.computerName = "Jason";

  services.syncthing.settings.folders = {
    "Projects/Personal" = {
      path = "/Users/${user}/Projects/Personal";
      devices = ["jason" "jason"];
    };
  };

  sops.secrets = {
    jason-syncthing-cert = {
      sopsFile = ../../secrets/jason-syncthing-cert;
      format = "binary";
      owner = user;
      path = "/Users/${user}/.config/syncthing/cert.pem";
    };
    jason-syncthing-key = {
      sopsFile = ../../secrets/jason-syncthing-key;
      format = "binary";
      owner = user;
      path = "/Users/${user}/.config/syncthing/key.pem";
    };
  };

  home-manager.users.${user} = {
    programs.git.settings.user.email = "christoph@schmatzler.com";
  };
}
