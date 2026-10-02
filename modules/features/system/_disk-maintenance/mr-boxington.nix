{
  lib,
  stdenvNoCC,
  fetchurl,
}:
stdenvNoCC.mkDerivation {
  pname = "mr-boxington";
  version = "1.21.0";
  # Match the shared rust-style tooling; nixpkgs does not package mbx yet.
  src = fetchurl {
    url = "https://github.com/jdx/mr-boxington/releases/download/v1.21.0/mbx-x86_64-unknown-linux-musl.tar.gz";
    hash = "sha256-UiWjt3+Q4c09HvDRBUzNRZOuGbLJi4Fa8bgqTf7Q+Xs=";
  };
  sourceRoot = ".";
  dontConfigure = true;
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    install -Dm755 mbx "$out/bin/mbx"
    runHook postInstall
  '';
  meta = {
    description = "Shared compiler cache for Cargo builds";
    homepage = "https://mr-boxington.jdx.dev";
    license = lib.licenses.mit;
    platforms = ["x86_64-linux"];
    mainProgram = "mbx";
  };
}
