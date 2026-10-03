{
  lib,
  stdenvNoCC,
  fetchurl,
}: let
  version = "1.21.1";
  releases = {
    x86_64-linux = {
      target = "x86_64-unknown-linux-musl";
      hash = "sha256-eAzLUqo6lawbDuDs9RhFYbGkvfH+iBgDM9wOEakpgPU=";
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux-musl";
      hash = "sha256-gPvVEKPpzudjrUDLrb+/IvxUrwJYn8/Y8AcNcFhJNVM=";
    };
    aarch64-darwin = {
      target = "aarch64-apple-darwin";
      hash = "sha256-mUZKW62Ww6RycU+qQneqwiGT6po4XdCYkvXBu+6cVro=";
    };
  };
  release = releases.${stdenvNoCC.hostPlatform.system};
in
  stdenvNoCC.mkDerivation {
    pname = "mr-boxington";
    inherit version;
    src = fetchurl {
      url = "https://github.com/jdx/mr-boxington/releases/download/v${version}/mbx-${release.target}.tar.gz";
      inherit (release) hash;
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
      platforms = builtins.attrNames releases;
      mainProgram = "mbx";
    };
  }
