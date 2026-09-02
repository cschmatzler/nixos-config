{
  lib,
  pkgs,
  ...
}: {
  systemd = {
    # 65532 is the distroless image's nonroot UID/GID.
    tmpfiles.rules = [
      "d /var/lib/executor 0700 65532 65532 -"
    ];

    services.docker-executor.serviceConfig.ExecStartPost = "${pkgs.curl}/bin/curl --fail --silent --show-error --connect-timeout 2 --max-time 5 --retry 12 --retry-delay 5 --retry-max-time 60 --retry-connrefused --retry-all-errors http://127.0.0.1:4788/api/health";

    services.executor-tailscale = (import ../../../_lib/tailscale-serve-exposure.nix {inherit lib;}) {
      inherit pkgs;
      port = 4788;
      workload = "Executor";
      identity = "svc:executor";
      orderingUnits = ["docker-executor.service"];
    };
  };

  virtualisation.oci-containers = {
    backend = "docker";
    containers.executor = {
      image = "ghcr.io/usefulsoftwareco/executor-selfhost:1.6.7";
      pull = "always";
      ports = ["127.0.0.1:4788:4788"];
      volumes = ["/var/lib/executor:/data"];
      user = "65532:65532";
      capabilities.ALL = false;
      environment = {
        EXECUTOR_ALLOW_LOCAL_NETWORK = "false";
        EXECUTOR_WEB_BASE_URL = "https://${(import ../../../_lib/local.nix).tailscaleHost "executor"}";
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
}
