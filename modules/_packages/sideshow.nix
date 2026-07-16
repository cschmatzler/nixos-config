{
  buildNpmPackage,
  fetchFromGitHub,
  lib,
  nodejs_24,
}:
buildNpmPackage rec {
  pname = "sideshow";
  version = "0.11.1";

  src = fetchFromGitHub {
    owner = "modem-dev";
    repo = "sideshow";
    rev = "v${version}";
    hash = "sha256-TFa4a2S756IIZVZNGn0BN3TMumLB8PL9W8lswfR34Mc=";
  };

  npmDepsHash = "sha256-uEWqzEsXTSAzobcHvheMztJ3hUXQB82pcfTddD6y2Ag=";
  nodejs = nodejs_24;

  meta = {
    description = "Live visual surface for terminal coding agents";
    homepage = "https://github.com/modem-dev/sideshow";
    license = lib.licenses.mit;
    mainProgram = "sideshow";
    platforms = lib.platforms.unix;
  };
}
