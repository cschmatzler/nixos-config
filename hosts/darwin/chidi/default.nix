{
  pkgs,
  user,
  ...
}: {
  imports = [
    ../shared.nix
  ];

  networking.hostName = "chidi";
  networking.computerName = "Chidi";

  services.syncthing.settings.folders = {
    "Projects/Work" = {
      path = "/Users/${user}/Projects/Work";
      devices = ["tahani" "chidi"];
    };
  };

  home-manager.users.${user} = {
    programs.git.settings.user.email = "christoph@tuist.dev";
  };

  environment.systemPackages = with pkgs; [
    slack
  ];
}
