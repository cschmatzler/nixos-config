_: let
  local = import ../../_lib/local.nix;
in {
  den.aspects.t3code = {
    darwin = {
      inputs',
      lib,
      ...
    }: {
      environment.systemPackages = [inputs'.llm-agents.packages.t3code-desktop];
      system.defaults.dock.persistent-apps = lib.mkAfter ["/Applications/Nix Apps/T3 Code (Alpha).app"];
    };

    # Headless server, exposed as https://t3.<tailnet>. Pairing token: `journalctl -u t3code`.
    nixos = {
      inputs',
      lib,
      pkgs,
      ...
    }: let
      home = local.mkHome pkgs.stdenv.hostPlatform.system;
    in {
      systemd.services = {
        t3code = {
          description = "T3 Code server";
          wantedBy = ["multi-user.target"];
          wants = ["network-online.target"];
          after = ["network-online.target"];
          # Agents (claude, codex, opencode) come from the user's Home Manager profile.
          path = ["${home}/.nix-profile" "/run/current-system/sw" "/run/wrappers"];
          serviceConfig = {
            User = local.user.name;
            WorkingDirectory = home;
            ExecStart = "${lib.getExe inputs'.llm-agents.packages.t3code} serve --host 127.0.0.1 --port 3773";
            Restart = "on-failure";
            RestartSec = "5s";
          };
        };
        t3code-tailscale = import ../../_lib/tailscale-serve.nix {
          inherit pkgs;
          identity = "svc:t3";
          port = 3773;
          after = ["t3code.service"];
        };
      };
    };
  };
}
