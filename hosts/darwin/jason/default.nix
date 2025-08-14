{user, ...}: {
  imports = [
    ../shared.nix
  ];

  networking.hostName = "jason";
  networking.computerName = "Jason";

  services.syncthing.settings.folders = {
    "Projects/Personal" = {
      path = "/Users/${user}/Projects/Personal";
      devices = ["tahani" "jason"];
    };
  };

  home-manager.users.${user} = {
    programs.git.userEmail = "christoph@schmatzler.com";
  };
}
