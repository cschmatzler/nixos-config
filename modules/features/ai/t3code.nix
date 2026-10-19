_: let
  local = import ../../_lib/local.nix;
  nightlyVersion = "0.1.1-nightly.20261019.3348";
in {
  den.aspects.t3code = {
    nixos = {
      lib,
      pkgs,
      ...
    }: let
      home = local.mkHome pkgs.stdenv.hostPlatform.system;
      t3code = pkgs.writeShellApplication {
        name = "t3";
        runtimeInputs = [pkgs.nodejs_26];
        text = ''exec npx --yes --ignore-scripts t3@${nightlyVersion} "$@"'';
      };
    in {
      environment.systemPackages = [t3code];

      systemd.services = {
        t3code = {
          description = "T3 Code server";
          wantedBy = ["multi-user.target"];
          wants = ["network-online.target"];
          after = ["network-online.target"];
          # Agent executables come from the user's Home Manager profile.
          path = ["${home}/.nix-profile" "/run/current-system/sw" "/run/wrappers"];
          serviceConfig = {
            User = local.user.name;
            WorkingDirectory = home;
            ExecStart = "${lib.getExe t3code} serve --host 127.0.0.1 --port 3773";
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

    # Preserve the release app's code signature; its updater cannot write to the store.
    darwin = {
      lib,
      pkgs,
      ...
    }: let
      build = {
        arch = "arm64";
        hash = "sha256-smGT9CHq4bmK3Qy1Kn3JwVfYnv/R+hEhHbK/fEzs1sg=";
      };
      desktop = import ../../_lib/darwin-app.nix {
        inherit pkgs;
        pname = "t3code-desktop";
        version = nightlyVersion;
        appName = "T3 Code (Nightly)";

        src = pkgs.fetchurl {
          name = "T3-Code-${nightlyVersion}-${build.arch}.zip";
          url = "https://github.com/pingdotgg/t3code/releases/download/v${nightlyVersion}/T3-Code-${nightlyVersion}-${build.arch}.zip";
          inherit (build) hash;
        };

        meta = {
          description = "Nightly desktop build of T3 Code";
          homepage = "https://t3.codes";
          downloadPage = "https://t3.codes/download";
          changelog = "https://github.com/pingdotgg/t3code/releases/tag/v${nightlyVersion}";
          license = lib.licenses.mit;
        };
      };
    in {
      environment.systemPackages = [desktop];
    };
  };
}
