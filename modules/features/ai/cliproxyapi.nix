_: {
  den.aspects.cliproxyapi.nixos = {
    config,
    pkgs,
    ...
  }: {
    sops.secrets = {
      cliproxyapi-api-key = {
        sopsFile = ../../../secrets/cliproxyapi;
        key = "api-key";
      };
      cliproxyapi-management-key = {
        sopsFile = ../../../secrets/cliproxyapi;
        key = "management-key";
      };
    };

    # Seed a writable configuration once; subsequent edits belong to the web UI.
    # JSON is valid YAML; SOPS replaces placeholders with secrets at activation.
    sops.templates."cliproxyapi-config.yaml".content = builtins.toJSON {
      host = "";
      port = 8317;
      auth-dir = "/data/auth";
      api-keys = [config.sops.placeholder.cliproxyapi-api-key];
      remote-management = {
        # Tailscale Serve reaches the container through its bridge network.
        allow-remote = true;
        secret-key = config.sops.placeholder.cliproxyapi-management-key;
        disable-control-panel = false;
      };
      usage-statistics-enabled = true;
      ws-auth = true;
    };

    virtualisation.oci-containers = {
      backend = "docker";
      containers.cliproxyapi = {
        image = "eceasy/cli-proxy-api:v7.2.157@sha256:7ad14e95aa5347325a0f727cb9be30673f619369624b9fc89673da60736f7cb5";
        cmd = ["./CLIProxyAPI" "-config" "/data/config.yaml"];
        ports = ["127.0.0.1:8317:8317"];
        volumes = ["/var/lib/cliproxyapi:/data"];
        environment = {
          TZ = config.time.timeZone;
          MANAGEMENT_STATIC_PATH = "/data/static";
        };
        extraOptions = ["--security-opt=no-new-privileges:true" "--cap-drop=ALL"];
      };
    };

    systemd.services = {
      docker-cliproxyapi = {
        requires = ["sops-install-secrets.service"];
        after = ["sops-install-secrets.service"];
        serviceConfig = {
          StateDirectory = "cliproxyapi";
          StateDirectoryMode = "0700";
          UMask = "0077";
          ExecStartPre = [
            "${pkgs.bash}/bin/bash ${./_cliproxyapi/initialize.sh} ${config.sops.templates."cliproxyapi-config.yaml".path}"
          ];
        };
        path = [pkgs.coreutils];
      };
      cliproxyapi-tailscale = import ../../_lib/tailscale-serve.nix {
        inherit pkgs;
        identity = "svc:cliproxyapi";
        port = 8317;
        after = ["docker-cliproxyapi.service"];
      };
    };
  };
}
