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
      ./kit
    ];
  };
  nodeModules = pkgs.importNpmLock.buildNodeModules {
    npmRoot = ./.;
    nodejs = pkgs.nodejs_24;
  };
in
  pkgs.stdenvNoCC.mkDerivation {
    pname = "herdr-docker-sandbox";
    version = "0.1.0";
    src = source;

    nativeBuildInputs = [
      pkgs.makeWrapper
      pkgs.nodejs_24
    ];

    # Kit files execute in Ubuntu, not in the NixOS host closure.
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
      kit="$out/share/herdr-sandbox/kit"
      mkdir -p "$out/bin" "$runtime/dist" "$kit"
      cp package.json "$runtime/package.json"
      cp -r dist/. "$runtime/dist/"

      makeWrapper ${pkgs.nodejs_24}/bin/node "$out/bin/herdr-sandboxd" \
        --add-flags "$runtime/dist/daemon.mjs"

      cp -r kit/. "$kit/"
      mkdir -p "$kit/files/home/.local/lib/herdr-sandbox"
      cp "$runtime/dist/guest/herdr-relay.mjs" \
        "$kit/files/home/.local/lib/herdr-sandbox/herdr-relay.mjs"
      chmod 0755 "$kit/files/home/.local/bin/herdr-sandbox-fish"

      runHook postInstall
    '';

    meta = {
      description = "Docker Sandboxes integration for isolated Herdr workspaces";
      license = lib.licenses.mit;
      mainProgram = "herdr-sandboxd";
      platforms = ["x86_64-linux"];
    };
  }
