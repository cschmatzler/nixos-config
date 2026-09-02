{pkgs}: let
  version = "1.1.0";
  platform = "linux-x64";
in
  pkgs.stdenvNoCC.mkDerivation {
    pname = "collie";
    inherit version;

    src = pkgs.fetchurl {
      url = "https://github.com/AltanS/collie/releases/download/v${version}/collie-${version}-${platform}.tar.gz";
      hash = "sha256-ovccwYNn8ZwcQoqNLVnZc0C8N7QcGgs1qOVJBltODL8=";
    };

    sourceRoot = "collie-${version}-${platform}";
    nativeBuildInputs = [pkgs.autoPatchelfHook];
    buildInputs = [pkgs.glibc];
    dontBuild = true;

    installPhase = ''
      runHook preInstall

      cp -R . "$out"
      mkdir -p "$out/scripts"
      cat >"$out/scripts/collie-ctl.sh" <<'EOF'
      #!${pkgs.runtimeShell}
      set -eu

      case "''${1:-}" in
        start|stop|restart)
          exec ${pkgs.systemd}/bin/systemctl --user "$1" collie.service
          ;;
        uninstall)
          ${pkgs.systemd}/bin/systemctl --user stop collie.service
          echo "Collie is managed by Nix; remove it from the Herdr aspect to uninstall it." >&2
          ;;
        update|update-major)
          echo "Collie is managed by Nix; update it in modules/features/ai/_herdr/collie.nix." >&2
          exit 1
          ;;
        *)
          exec @out@/bin/collie "$@"
          ;;
      esac
      EOF
      substituteInPlace "$out/scripts/collie-ctl.sh" --replace-fail @out@ "$out"
      chmod +x "$out/scripts/collie-ctl.sh"

      runHook postInstall
    '';

    meta = {
      description = "Mobile web UI for Herdr agents";
      homepage = "https://colliepwa.dev/";
      license = pkgs.lib.licenses.mit;
      mainProgram = "collie";
      platforms = ["x86_64-linux"];
    };
  }
