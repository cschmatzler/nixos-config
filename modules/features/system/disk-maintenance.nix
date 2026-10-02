_: {
  den.aspects.disk-maintenance = {
    nixos = {
      config,
      lib,
      ...
    }: {
      nix.gc.dates = "daily";
      nix.settings = {
        min-free = 100 * 1024 * 1024 * 1024;
        max-free = 200 * 1024 * 1024 * 1024;
      };

      systemd.tmpfiles.settings.tmp = {
        "/tmp".q = {
          mode = "1777";
          user = "root";
          group = "root";
          age = "2d";
        };
        "/var/tmp".q = {
          mode = "1777";
          user = "root";
          group = "root";
          age = "7d";
        };
      };
      systemd.timers.systemd-tmpfiles-clean.timerConfig.OnUnitActiveSec = "1h";
      services.journald.settings.Journal.SystemMaxUse = "1G";

      virtualisation.docker = lib.mkIf config.virtualisation.docker.enable {
        daemon.settings.builder.gc = {
          enabled = true;
          defaultKeepStorage = "30GB";
        };
        autoPrune = {
          enable = true;
          dates = "daily";
          flags = ["--all" "--filter" "until=168h"];
        };
      };
    };

    homeManager = {
      config,
      lib,
      pkgs,
      ...
    }:
      lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
        xdg.configFile."mbx/config.toml".source = ./_disk-maintenance/mbx.toml;

        systemd.user.services.mbx-gc = {
          Unit.Description = "Collect Rust build caches within their shared budget";
          Service = {
            Type = "oneshot";
            ExecStart = "${config.home.profileDirectory}/bin/mbx gc";
            Nice = 10;
            IOSchedulingClass = "idle";
          };
        };
        systemd.user.timers.mbx-gc = {
          Unit.Description = "Hourly Rust build cache collection";
          Timer = {
            OnCalendar = "hourly";
            Persistent = true;
            RandomizedDelaySec = "5m";
          };
          Install.WantedBy = ["timers.target"];
        };
      };
  };
}
