_: let
  local = import ../../_lib/local.nix;
in {
  den.aspects.t3code = {
    # Headless server, exposed as https://t3.<tailnet>. Pairing token: `journalctl -u t3code`.
    nixos = {pkgs, ...}: let
      home = local.mkHome pkgs.stdenv.hostPlatform.system;
      t3code = inputs'.llm-agents.packages.t3code;
      relayEnvironment = {
        # Public production identifiers from https://github.com/pingdotgg/t3code/blob/main/.env.example.
        # Source-built packages do not bake these in, so provide them at runtime.
        T3CODE_RELAY_URL = "https://relay.t3.codes";
        T3CODE_CLERK_PUBLISHABLE_KEY = "pk_live_Y2xlcmsudDMuY29kZXMk";
        T3CODE_CLERK_CLI_OAUTH_CLIENT_ID = "hzxSgY2cH10sDU2r";
        # Prefer the Nix package even if T3 previously downloaded its own client.
        T3CODE_CLOUDFLARED_PATH = lib.getExe pkgs.cloudflared;
      };
    in {
      environment.systemPackages = [t3code pkgs.cloudflared];
      environment.variables = relayEnvironment;

      systemd.services = {
        t3code = {
          description = "T3 Code server";
          wantedBy = ["multi-user.target"];
          wants = ["network-online.target"];
          after = ["network-online.target"];
          environment = relayEnvironment;
          # Agents (claude, codex, opencode) come from the user's Home Manager profile.
          path = ["${home}/.nix-profile" "/run/current-system/sw" "/run/wrappers"];
          serviceConfig = {
            User = local.user.name;
            WorkingDirectory = home;
            ExecStart = "${pkgs.nodejs_24}/bin/npx --yes t3@nightly serve --host 127.0.0.1 --port 3773";
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
