{
  fetchurl,
  lib,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation rec {
  pname = "better-thermostat-ui-card";
  version = "3.3.0";

  src = fetchurl {
    url = "https://github.com/KartoffelToby/better-thermostat-ui-card/releases/download/${version}/better-thermostat-ui-card.js";
    hash = "sha256-dRUhL+Y0gRT+n5OnVY2lwrIkow2RV0wiM+tqampEEMY=";
  };

  dontUnpack = true;
  installPhase = ''
    runHook preInstall

    install -Dm444 "$src" "$out/better-thermostat-ui-card.js"

    runHook postInstall
  '';

  passthru.entrypoint = "better-thermostat-ui-card.js";

  meta = {
    description = "Lovelace UI card for Better Thermostat";
    homepage = "https://github.com/KartoffelToby/better-thermostat-ui-card";
    license = lib.licenses.agpl3Only;
    platforms = lib.platforms.all;
  };
}
