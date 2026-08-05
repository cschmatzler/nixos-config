{
  fetchurl,
  lib,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation rec {
  pname = "ha-floorplan";
  version = "1.1.4";

  src = fetchurl {
    url = "https://github.com/ExperienceLovelace/ha-floorplan/releases/download/v${version}/floorplan.js";
    hash = "sha256-EwyT3tKjkObuYn5pXkP9mvvRwHyaGLpieX4M0nKihDk=";
  };

  dontUnpack = true;
  installPhase = ''
    runHook preInstall

    install -Dm444 "$src" "$out/floorplan.js"

    runHook postInstall
  '';

  passthru.entrypoint = "floorplan.js";

  meta = {
    description = "Bring floor plans to Home Assistant";
    homepage = "https://experiencelovelace.github.io/ha-floorplan/";
    license = lib.licenses.asl20;
    platforms = lib.platforms.all;
  };
}
