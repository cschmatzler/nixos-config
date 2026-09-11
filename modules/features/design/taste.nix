{den, ...}: {
  den.aspects.taste.darwin = {
    lib,
    pkgs,
    ...
  }: let
    taste = pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
      pname = "taste";
      version = "0.3.0";

      src = pkgs.fetchurl {
        name = "Taste-${finalAttrs.version}.zip";
        url = "https://buildwithtaste.com/downloads/Taste-${finalAttrs.version}.zip";
        hash = "sha256-gaf+4/N5EwCdvS8NIYgC1JrACXPSYp8GmPMaMGYBP9s=";
      };

      nativeBuildInputs = [pkgs._7zz];
      unpackCmd = "7zz x -snld20 -xr'!*:com.apple.*' $curSrc";
      sourceRoot = "Taste.app";

      dontPatch = true;
      dontConfigure = true;
      dontBuild = true;
      dontFixup = true;

      installPhase = ''
        runHook preInstall

        mkdir -p "$out/Applications/Taste.app"
        cp -R . "$out/Applications/Taste.app"

        runHook postInstall
      '';

      meta = {
        description = "Build a reusable design taste profile for AI coding tools";
        homepage = "https://buildwithtaste.com";
        changelog = "https://buildwithtaste.com/appcast.xml";
        license = lib.licenses.unfree;
        sourceProvenance = [lib.sourceTypes.binaryNativeCode];
        platforms = lib.platforms.darwin;
      };
    });
  in {
    environment.systemPackages = [taste];
  };
}
