{
  lib,
  pkgs,
  ...
}: let
  local = import ../../../_lib/local.nix;
  home = local.mkHome pkgs.stdenv.hostPlatform.system;
  apiKeyPath = local.secretPath "opencode-api-key";
  homeAssistantTokenPath = local.secretPath "home-assistant-token";
  version = "0.0.29-nightly.20260723.880";
in {
  sops.secrets = {
    home-assistant-token.restartUnits = ["t3-code.service"];
    opencode-api-key.restartUnits = ["t3-code.service"];
  };

  systemd.services = {
    t3-code = {
      description = "T3 Code server";
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"];
      after = ["network-online.target"];
      environment = {
        HOME = home;
        PATH = lib.mkForce "${lib.makeBinPath [pkgs.gcc pkgs.gnumake pkgs.python3]}:${home}/.nix-profile/bin:/run/current-system/sw/bin:/run/wrappers/bin";
        PYTHON = lib.getExe pkgs.python3;
      };
      script = ''
        export OPENCODE_API_KEY="$(<${apiKeyPath})"
        export HOME_ASSISTANT_TOKEN="$(<${homeAssistantTokenPath})"
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
  };
}
