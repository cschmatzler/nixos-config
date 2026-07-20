{
  fetchurl,
  lib,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation rec {
  pname = "scheduler-card";
  version = "4.0.9";

  src = fetchurl {
    url = "https://github.com/nielsfaber/scheduler-card/releases/download/v${version}/scheduler-card.js";
    hash = "sha256-5BK8JjrgoKtj/4MstFnz2BzqdaNodIUJNhqJA20tFE0=";
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
