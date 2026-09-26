_: let
  local = import ../../_lib/local.nix;
  nightlyVersion = "0.0.43-nightly.20260926.2282";
in {
  den.aspects.t3code = {
    # Headless server, exposed as https://t3.<tailnet>. Pairing token: `journalctl -u t3code`.
    nixos = {
      lib,
      pkgs,
      ...
    }: let
      home = local.mkHome pkgs.stdenv.hostPlatform.system;
      t3code = pkgs.writeShellApplication {
        name = "t3";
        runtimeInputs = [pkgs.nodejs_24];
        text = ''exec npx --yes --ignore-scripts t3@${nightlyVersion} "$@"'';
      };
      relayEnvironment = {
        # Public production identifiers from https://github.com/pingdotgg/t3code/blob/main/.env.example.
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

    # Nightly desktop app on the Macs. The release .app is code signed, so install
    # it untouched; the built-in updater still runs but cannot write to the store.
    darwin = {
      lib,
      pkgs,
      ...
    }: let
      build = {
        arch = "arm64";
        hash = "sha256-loXhpEje7jJNFD+nt7i5NxYCXCz5ydzv0ZgnsXQyC/M=";
      };
      appName = "T3 Code (Nightly)";
      desktop = pkgs.stdenvNoCC.mkDerivation {
        pname = "t3code-desktop";
        version = nightlyVersion;

        src = pkgs.fetchurl {
          name = "T3-Code-${nightlyVersion}-${build.arch}.zip";
          url = "https://github.com/pingdotgg/t3code/releases/download/v${nightlyVersion}/T3-Code-${nightlyVersion}-${build.arch}.zip";
          inherit (build) hash;
        };

        nativeBuildInputs = [pkgs._7zz];
        unpackCmd = "7zz x -snld20 -xr'!*:com.apple.*' $curSrc";
        sourceRoot = "${appName}.app";

        dontPatch = true;
        dontConfigure = true;
        dontBuild = true;
        dontFixup = true;

        installPhase = ''
          runHook preInstall

          mkdir -p "$out/Applications/${appName}.app"
          cp -R . "$out/Applications/${appName}.app"

          runHook postInstall
        '';

        meta = {
          description = "Nightly desktop build of T3 Code";
          homepage = "https://t3.codes";
          downloadPage = "https://t3.codes/download";
          changelog = "https://github.com/pingdotgg/t3code/releases/tag/v${nightlyVersion}";
          license = lib.licenses.mit;
          platforms = lib.platforms.darwin;
          sourceProvenance = [lib.sourceTypes.binaryNativeCode];
        };
      };
    in {
      environment.systemPackages = [desktop];
    };
  };
}
