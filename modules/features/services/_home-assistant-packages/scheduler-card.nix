{
  fetchurl,
  lib,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation rec {
  pname = "scheduler-card";
  version = "4.0.19";

  src = fetchurl {
    url = "https://github.com/nielsfaber/scheduler-card/releases/download/v${version}/scheduler-card.js";
    hash = "sha256-UDOrixd2Xn3lo3K5Kb9M1gdgYCZz55ejJECg2FrMFzs=";
  };

  dontUnpack = true;
  installPhase = ''
    runHook preInstall

    install -Dm444 "$src" "$out/scheduler-card.js"

    runHook postInstall
  '';

  passthru.entrypoint = "scheduler-card.js";

  meta = {
    description = "Lovelace card for Scheduler entities";
    homepage = "https://github.com/nielsfaber/scheduler-card";
    license = lib.licenses.gpl3Plus;
    platforms = lib.platforms.all;
  };
}
