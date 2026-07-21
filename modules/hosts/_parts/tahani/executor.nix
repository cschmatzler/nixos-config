{pkgs, ...}: let
  local = import ../../../_lib/local.nix;
  port = 4788;
  url = "https://${local.tailscaleHost "executor"}";
in {
  # 65532 is the distroless image's nonroot UID/GID.
  systemd.tmpfiles.rules = [
    "d /var/lib/executor 0700 65532 65532 -"
  ];

  virtualisation.oci-containers = {
    backend = "docker";
    containers.executor = {
      image = "ghcr.io/usefulsoftwareco/executor-selfhost:1.5.35@sha256:e0063e0d6cfcff5624a4447e569e16d97439510283f6962d143888789efe932f";
      pull = "always";
      ports = ["127.0.0.1:${toString port}:${toString port}"];
      volumes = ["/var/lib/executor:/data"];
      user = "65532:65532";
      capabilities.ALL = false;
      environment = {
        EXECUTOR_ALLOW_LOCAL_NETWORK = "false";
        EXECUTOR_WEB_BASE_URL = url;
        HOME = "/tmp";
        TMPDIR = "/tmp";
      };
      extraOptions = [
        # The upstream distroless image's shell-form health check cannot run.
        "--no-healthcheck"
        "--read-only"
        "--security-opt=no-new-privileges=true"
        "--tmpfs=/tmp:rw,nosuid,nodev,noexec,size=64m,mode=1777"
        "--cpus=4"
        "--memory=2g"
        "--memory-swap=2g"
        "--pids-limit=256"
      ];
    };
  };

  systemd.services.docker-executor.serviceConfig.ExecStartPost = "${pkgs.curl}/bin/curl --fail --silent --show-error --connect-timeout 2 --max-time 5 --retry 12 --retry-delay 5 --retry-max-time 60 --retry-connrefused --retry-all-errors http://127.0.0.1:${toString port}/api/health";

  systemd.services.executor-tailscale = {
    description = "Expose Executor through Tailscale Serve";
    wantedBy = ["multi-user.target"];
    requires = ["docker-executor.service" "tailscaled.service"];
    after = ["docker-executor.service" "tailscaled.service"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.tailscale}/bin/tailscale serve --yes --service=svc:executor --https=443 http://127.0.0.1:${toString port}";
      ExecStop = "${pkgs.tailscale}/bin/tailscale serve --yes --service=svc:executor --https=443 off";
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };
}
