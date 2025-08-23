{
  config,
  lib,
  pkgs,
  user,
  ...
}: {
  config = lib.mkIf config.services.postgresql.enable {
    services.postgresql = {
      package = pkgs.postgresql_17;
      enableTCPIP = true;
      settings.port = 5432;
      ensureDatabases = ["postgres"];
      ensureUsers = [
        {
          name = "postgres";
          ensureDBOwnership = true;
        }
        {
          name = user;
          ensureClauses = {
            superuser = true;
            createdb = true;
          };
        }
      ];
      authentication = ''
        local all all trust
        host  all all 127.0.0.1/32 trust
        host  all all ::1/128 trust
      '';
    };
  };
}
