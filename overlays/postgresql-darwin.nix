final: prev: {
  postgresql = {
    config,
    lib,
    ...
  }: let
    cfg = config.services.postgresql;

    postStartScript = prev.writeScript "postgresql-post-start" ''
      #!${prev.bash}/bin/bash
      set -e

      # Wait for PostgreSQL to be ready
      until ${cfg.package}/bin/pg_isready -h localhost -p ${toString cfg.port} -U ${cfg.superUser}; do
        sleep 1
      done

      # Create databases if they don't exist
      ${prev.lib.concatMapStringsSep "\n" (db: ''
          if ! ${cfg.package}/bin/psql -h localhost -p ${toString cfg.port} -U ${cfg.superUser} -lqt | cut -d'|' -f1 | grep -qw ${prev.lib.escapeShellArg db}; then
            echo "Creating database: ${prev.lib.escapeShellArg db}"
            ${cfg.package}/bin/createdb -h localhost -p ${toString cfg.port} -U ${cfg.superUser} ${prev.lib.escapeShellArg db}
          fi
        '')
        cfg.ensureDatabases}

      # Create users and set permissions
      ${prev.lib.concatMapStringsSep "\n" (user: ''
          # Create user if it doesn't exist
          if ! ${cfg.package}/bin/psql -h localhost -p ${toString cfg.port} -U ${cfg.superUser} -tAc "SELECT 1 FROM pg_roles WHERE rolname='${prev.lib.escapeShellArg user.name}'" | grep -q 1; then
            echo "Creating user: ${prev.lib.escapeShellArg user.name}"
            ${cfg.package}/bin/psql -h localhost -p ${toString cfg.port} -U ${cfg.superUser} -c "CREATE USER \"${prev.lib.escapeShellArg user.name}\""
          fi

          # Set user privileges
          ${prev.lib.optionalString (user ? ensureDBOwnership && user.ensureDBOwnership) ''
            echo "Setting database ownership for ${prev.lib.escapeShellArg user.name}"
            ${cfg.package}/bin/psql -h localhost -p ${toString cfg.port} -U ${cfg.superUser} -c "ALTER USER \"${prev.lib.escapeShellArg user.name}\" CREATEDB CREATEROLE"
          ''}

          ${prev.lib.optionalString (user ? ensureClauses) ''
            ${prev.lib.optionalString (user.ensureClauses ? superuser && user.ensureClauses.superuser) ''
              echo "Granting superuser to ${prev.lib.escapeShellArg user.name}"
              ${cfg.package}/bin/psql -h localhost -p ${toString cfg.port} -U ${cfg.superUser} -c "ALTER USER \"${prev.lib.escapeShellArg user.name}\" SUPERUSER"
            ''}
            ${prev.lib.optionalString (user.ensureClauses ? createdb && user.ensureClauses.createdb) ''
              echo "Granting createdb to ${prev.lib.escapeShellArg user.name}"
              ${cfg.package}/bin/psql -h localhost -p ${toString cfg.port} -U ${cfg.superUser} -c "ALTER USER \"${prev.lib.escapeShellArg user.name}\" CREATEDB"
            ''}
          ''}

          # Grant permissions (legacy support)
          ${prev.lib.concatMapStringsSep "\n" (perm: ''
            echo "Granting ${prev.lib.escapeShellArg perm} to ${prev.lib.escapeShellArg user.name}"
            ${cfg.package}/bin/psql -h localhost -p ${toString cfg.port} -U ${cfg.superUser} -c "GRANT ${prev.lib.escapeShellArg perm} TO \"${prev.lib.escapeShellArg user.name}\""
          '') (prev.lib.optionals (user ? ensurePermissions) (prev.lib.mapAttrsToList (target: perm: "${perm} ON ${target}") user.ensurePermissions))}
        '')
        cfg.ensureUsers}

      # Run initial script if provided
      ${prev.lib.optionalString (cfg.initialScript != null) ''
        echo "Running initial script"
        ${cfg.package}/bin/psql -h localhost -p ${toString cfg.port} -U ${cfg.superUser} -f ${cfg.initialScript}
      ''}
    '';
  in {
    config = prev.lib.mkIf cfg.enable {
      launchd.user.agents.postgresql = prev.lib.mkIf (cfg.ensureDatabases != [] || cfg.ensureUsers != [] || cfg.initialScript != null) {
        script = prev.lib.mkAfter ''
          # Run post-start script in background after PostgreSQL starts
          (
            sleep 5  # Give PostgreSQL a moment to fully start
            ${prev.bash}/bin/bash ${postStartScript}
          ) &
        '';
      };
    };
  };
}
