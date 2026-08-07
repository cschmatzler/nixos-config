{
  lib,
  pkgs,
  ...
}: let
  local = import ../../../_lib/local.nix;
  mkTailscaleServeExposure = import ../../../_lib/tailscale-serve-exposure.nix {inherit lib;};
  home = local.mkHome pkgs.stdenv.hostPlatform.system;
  port = 30141;
  version = "0.8.5";
in {
  systemd.services = {
    pi-web = {
      description = "Pi web UI";
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"];
      after = ["network-online.target"];
      environment = {
        HOME = home;
        PATH = lib.mkForce "${home}/.nix-profile/bin:/run/current-system/sw/bin:/run/wrappers/bin";
        PI_CODING_AGENT_DIR = "${home}/.pi/agent";
        PI_SKIP_VERSION_CHECK = "1";
        PI_WEB_ALLOWED_HOSTS = local.tailscaleHost "pi";
        PI_WEB_NO_OPEN = "1";
        PLANNOTATOR_PORT = "20000";
        PLANNOTATOR_REMOTE = "1";
        SUPERMEMORY_API_URL = "https://api.supermemory.ai";
      };
      script = ''
        if [ -f "${local.secretPath "supermemory-api-key"}" ]; then
          export SUPERMEMORY_API_KEY="$(tr -d '\n' < "${local.secretPath "supermemory-api-key"}")"
        fi

        exec ${pkgs.nodejs_24}/bin/npx --yes @agegr/pi-web@${version} --hostname 127.0.0.1 --port ${toString port} --no-open
      '';
      serviceConfig = {
        User = local.user.name;
        WorkingDirectory = "${home}/nixos-config";
        Restart = "on-failure";
        RestartSec = "5s";
        ExecStartPost = "${pkgs.curl}/bin/curl --fail --silent --show-error --connect-timeout 2 --max-time 5 --retry 12 --retry-delay 5 --retry-max-time 60 --retry-connrefused --retry-all-errors http://127.0.0.1:${toString port}/";
      };
    };

    pi-web-tailscale = mkTailscaleServeExposure {
      inherit pkgs port;
      workload = "Pi";
      identity = "svc:pi";
      orderingUnits = ["pi-web.service"];
    };
  };
}
