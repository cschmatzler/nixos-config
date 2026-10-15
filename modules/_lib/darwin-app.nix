# Installs a prebuilt, code-signed macOS .app from a zip without modifying it.
{
  pkgs,
  pname,
  version,
  appName,
  src,
  meta ? {},
}:
pkgs.stdenvNoCC.mkDerivation {
  inherit pname version src;

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

  meta =
    {
      platforms = pkgs.lib.platforms.darwin;
      sourceProvenance = [pkgs.lib.sourceTypes.binaryNativeCode];
    }
    // meta;
}
