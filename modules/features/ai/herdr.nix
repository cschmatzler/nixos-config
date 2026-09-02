{inputs, ...}: {
  flake-file.inputs = {
    herdr = {
      url = "github:ogulcancelik/herdr";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    herdr-plugin-worktree-bootstrap = {
      url = "github:zerodice0/herdr-plugin-worktree-bootstrap/v0.4.0";
      flake = false;
    };
  };

  den.aspects.herdr.homeManager = {
    config,
    inputs',
    lib,
    pkgs,
    ...
  }: let
    local = import ../../_lib/local.nix;
    collie = import ./_herdr/collie.nix {inherit pkgs;};
    plugins = {
      gh-pr-workspace = ./_herdr/plugins/gh-pr-workspace;
      worktree-bootstrap = inputs.herdr-plugin-worktree-bootstrap;
    };
    pluginRegistry =
      builtins.map (source: let
        manifest = builtins.fromTOML (builtins.readFile "${source}/herdr-plugin.toml");
      in {
        plugin_id = manifest.id;
        inherit (manifest) name version min_herdr_version;
        manifest_path = "${source}/herdr-plugin.toml";
        plugin_root = "${source}";
        enabled = true;
        source.kind = "local";
      }) (builtins.attrValues plugins)
      ++ lib.optional pkgs.stdenv.hostPlatform.isLinux {
        plugin_id = "herdr.collie";
        name = "Collie";
        version = "1.1.0";
        min_herdr_version = "0.7.0";
        manifest_path = "${collie}/herdr-plugin.toml";
        plugin_root = "${collie}";
        enabled = true;
        source.kind = "local";
      };
  in {
    home = {
      packages =
        (with pkgs; [
          bun
          gh
          git
          inputs'.herdr.packages.herdr
        ])
        ++ lib.optional pkgs.stdenv.hostPlatform.isLinux collie;

      file = {
        ".config/herdr/config.toml".source = (pkgs.formats.toml {}).generate "herdr-config.toml" (import ./_herdr/config.nix {
          theme = import ../../_lib/theme.nix;
        });
        ".config/herdr/plugins.json".source = (pkgs.formats.json {}).generate "herdr-plugins.json" pluginRegistry;
        ".config/herdr/plugins/config/herdr.collie/.env" = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
          text = ''
            COLLIE_MUX=herdr
            COLLIE_SKIP_SERVE=1
            COLLIE_PUBLIC_HOSTS=${local.tailscaleHost "collie"}
            COLLIE_PUBLIC_URL=https://${local.tailscaleHost "collie"}
            COLLIE_TRUSTED_USER=${local.user.name}@github
            COLLIE_AUDIT_CONTENT=none
          '';
        };
      };
    };

    systemd.user.services.collie = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
      Unit = {
        Description = "Collie mobile UI for Herdr";
        StartLimitIntervalSec = 0;
      };
      Service = {
        Type = "simple";
        WorkingDirectory = "${collie}";
        ExecStart = "${collie}/bin/collie _exec-bridge";
        Restart = "on-failure";
        RestartSec = 5;
        NoNewPrivileges = true;
        PrivateTmp = true;
        Environment = [
          "HERDR_SOCKET_PATH=${config.home.homeDirectory}/.config/herdr/herdr.sock"
          "COLLIE_PORT=8787"
          "HERDR_PLUGIN_CONFIG_DIR=${config.home.homeDirectory}/.config/herdr/plugins/config/herdr.collie"
          "COLLIE_PLUGIN_ROOT=${collie}"
        ];
        EnvironmentFile = "-${config.home.homeDirectory}/.config/herdr/plugins/config/herdr.collie/.env";
      };
      Install.WantedBy = ["default.target"];
    };
  };

  den.aspects.herdr.nixos = {pkgs, ...}: {
    systemd.services.collie-tailscale = import ../../_lib/tailscale-serve.nix {
      inherit pkgs;
      identity = "svc:collie";
      port = 8787;
    };
  };
}
