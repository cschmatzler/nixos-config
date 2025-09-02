{
  config,
  lib,
  pkgs,
  user,
  ...
}: {
  imports = [
    ../shared.nix
    ../../../modules/postgresql.nix
  ];

  networking.hostName = "chidi";
  networking.computerName = "Chidi";

  services.postgresql = {
    enable = true;
  };

  services.syncthing.settings.folders = {
    "Projects/Work" = {
      path = "/Users/${user}/Projects/Work";
      devices = ["tahani" "chidi"];
    };
  };

  home-manager.users.${user} = {
    programs.git.userEmail = "christoph@tuist.dev";
  };

  environment.systemPackages = with pkgs; [
    slack
  ];
}
