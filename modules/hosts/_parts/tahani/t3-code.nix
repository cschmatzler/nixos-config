{
  lib,
  pkgs,
  ...
}: let
  local = import ../../../_lib/local.nix;
  home = local.mkHome pkgs.stdenv.hostPlatform.system;
  apiKeyPath = local.secretPath "opencode-api-key";
  version = "0.0.29-nightly.20260727.915";
in {
  sops.secrets.opencode-api-key.restartUnits = ["t3-code.service"];

  systemd.services = {
    t3-code = {
      description = "T3 Code server";
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"];
      after = ["network-online.target"];
      environment = {
        HOME = home;
        PATH = lib.mkForce "${lib.makeBinPath [pkgs.gcc pkgs.gnumake pkgs.python3]}:${home}/.nix-profile/bin:/run/current-system/sw/bin:/run/wrappers/bin";
        PLANNOTATOR_PORT = "20000";
        PLANNOTATOR_REMOTE = "0";
        PLANNOTATOR_SKIP_BROWSER_OPEN = "1";
        PYTHON = lib.getExe pkgs.python3;
      };
      script = ''
        export OPENCODE_API_KEY="$(<${apiKeyPath})"
        exec ${pkgs.nodejs_24}/bin/npx --yes t3@${version} serve --host 127.0.0.1 --port 3773
      '';
      serviceConfig = {
        User = local.user.name;
        WorkingDirectory = "${home}/nixos-config";
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };

    t3-code-tailscale = {
      description = "Expose T3 Code through Tailscale Serve";
      wantedBy = ["multi-user.target"];
      requires = ["t3-code.service" "tailscaled.service"];
      after = ["t3-code.service" "tailscaled.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.tailscale}/bin/tailscale serve --yes --service=svc:t3 --https=443 http://127.0.0.1:3773";
        ExecStop = "${pkgs.tailscale}/bin/tailscale serve --yes --service=svc:t3 --https=443 off";
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };

    plannotator-tailscale = {
      description = "Expose Plannotator through Tailscale Serve";
      wantedBy = ["multi-user.target"];
      requires = ["tailscaled.service"];
      after = ["tailscaled.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.tailscale}/bin/tailscale serve --yes --service=svc:plannotator --https=443 http://127.0.0.1:20000";
        ExecStop = "${pkgs.tailscale}/bin/tailscale serve --yes --service=svc:plannotator --https=443 off";
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
  };
}
