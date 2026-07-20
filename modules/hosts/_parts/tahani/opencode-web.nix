{
  inputs',
  lib,
  pkgs,
  ...
}: let
  local = import ../../../_lib/local.nix;
  home = local.mkHome pkgs.stdenv.hostPlatform.system;
  apiKeyPath = local.secretPath "opencode-api-key";
  passwordPath = local.secretPath "opencode-web-password";
  opencode = inputs'.llm-agents.packages.opencode;
in {
  sops.secrets.opencode-web-password = {
    owner = local.user.name;
    path = passwordPath;
    sopsFile = ../../../../secrets/opencode-web-password;
    format = "binary";
    restartUnits = ["opencode-web.service"];
  };

  systemd.services = {
    opencode-web = {
      description = "OpenCode web server";
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"];
      after = ["network-online.target"];
      environment = {
        HOME = home;
        PATH = lib.mkForce "${home}/.nix-profile/bin:/run/current-system/sw/bin:/run/wrappers/bin";
      };
      script = ''
        export OPENCODE_API_KEY="$(<${apiKeyPath})"
        export OPENCODE_SERVER_PASSWORD="$(<${passwordPath})"
        exec ${opencode}/bin/opencode web --hostname 127.0.0.1 --port 4096
      '';
      serviceConfig = {
        User = local.user.name;
        WorkingDirectory = "${home}/nixos-config";
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };

    opencode-web-tailscale = {
      description = "Expose OpenCode web through Tailscale Serve";
      wantedBy = ["multi-user.target"];
      requires = ["opencode-web.service" "tailscaled.service"];
      after = ["opencode-web.service" "tailscaled.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.tailscale}/bin/tailscale serve --yes --service=svc:opencode --https=443 http://127.0.0.1:4096";
        ExecStop = "${pkgs.tailscale}/bin/tailscale serve --yes --service=svc:opencode --https=443 off";
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
  };
}
