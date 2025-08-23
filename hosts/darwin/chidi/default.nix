{
  config,
  lib,
  pkgs,
  user,
  ...
}: {
  imports = [
    ../shared.nix
  ];

  networking.hostName = "chidi";
  networking.computerName = "Chidi";

  nixpkgs.overlays = [
    (import ../../../overlays/postgresql-darwin.nix)
  ];

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_17;
    enableTCPIP = true;
    port = 5432;
    ensureDatabases = ["postgres"];
    ensureUsers = [
      {
        name = "postgres";
        ensureDBOwnership = true;
      }
      {
        name = "cschmatzler";
        ensureClauses = {
          superuser = true;
          createdb = true;
        };
      }
    ];
    authentication = pkgs.lib.mkForce ''
      local all all trust
      host  all all 127.0.0.1/32 trust
      host  all all ::1/128 trust
    '';
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
