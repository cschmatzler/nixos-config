{
  lib,
  pkgs,
}: let
  source = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./package.json
      ./package-lock.json
      ./tsconfig.json
      ./src
      ./guest
    ];
  };
  nodeModules = pkgs.importNpmLock.buildNodeModules {
    npmRoot = ./.;
    nodejs = pkgs.nodejs_24;
  };
in
  pkgs.stdenvNoCC.mkDerivation {
    pname = "herdr-microvm-sandbox";
    version = "0.1.0";
    src = source;

    nativeBuildInputs = [
      pkgs.makeWrapper
      pkgs.nodejs_24
    ];

    # Guest files execute in the Ubuntu workspace, not in the NixOS host closure.
    dontPatchShebangs = true;

    buildPhase = ''
      runHook preBuild
      ln -s ${nodeModules}/node_modules node_modules
      npm run bundle
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      runtime="$out/libexec/herdr-sandbox"
      guestHome="$out/share/herdr-sandbox/home"
      mkdir -p "$out/bin" "$out/libexec" "$runtime/dist" "$guestHome"
      cp package.json "$runtime/package.json"
      cp -r dist/. "$runtime/dist/"

      makeWrapper ${pkgs.nodejs_24}/bin/node "$out/bin/herdr-sandboxd" \
        --add-flags "$runtime/dist/daemon.mjs"

      # Herdr identifies an attachable shell from the host foreground process.
      # A real copy keeps Linux's process name `fish` while preserving SSH's
      # normal argv handling.
      cp ${pkgs.openssh}/bin/ssh "$out/libexec/fish"
      chmod 0755 "$out/libexec/fish"

      cp -r guest/home/. "$guestHome/"
      mkdir -p "$guestHome/.local/lib/herdr-sandbox"
      cp "$runtime/dist/guest/herdr-relay.mjs" \
        "$guestHome/.local/lib/herdr-sandbox/herdr-relay.mjs"
      chmod 0755 \
        "$guestHome/.local/bin/herdr-sandbox-enter" \
        "$guestHome/.local/bin/herdr-sandbox-fish"

      runHook postInstall
    '';

    meta = {
      description = "microvm.nix integration for isolated Herdr workspaces";
      license = lib.licenses.mit;
      mainProgram = "herdr-sandboxd";
      platforms = ["x86_64-linux"];
    };
  }
