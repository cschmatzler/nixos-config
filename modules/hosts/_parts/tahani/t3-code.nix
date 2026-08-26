{
  inputs',
  lib,
  pkgs,
  ...
}: let
  local = import ../../../_lib/local.nix;
  home = local.mkHome pkgs.stdenv.hostPlatform.system;
  t3code = inputs'.llm-agents.packages.t3code;
in {
  systemd.services = {
    t3-code = {
      description = "T3 Code server";
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"];
      after = ["network-online.target"];
      environment = {
        HOME = home;
        PATH = lib.mkForce "${home}/.nix-profile/bin:/run/current-system/sw/bin:/run/wrappers/bin";
      };
      serviceConfig = {
        User = local.user.name;
        WorkingDirectory = home;
        ExecStart = "${lib.getExe t3code} serve --host 127.0.0.1 --port 3773";
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };

    t3-code-tailscale = (import ../../../_lib/tailscale-serve-exposure.nix {inherit lib;}) {
      inherit pkgs;
      port = 3773;
      workload = "T3 Code";
      identity = "svc:t3";
      orderingUnits = ["t3-code.service"];
    };
  };
}
