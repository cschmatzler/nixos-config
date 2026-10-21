{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  bun,
  git,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "gitcafe";
  version = "0.10.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/@gitcafe/cli/-/cli-${finalAttrs.version}.tgz";
    hash = "sha256-vvXkfSJB4lWrmheZmG1/o954BvTKsft9eLwaa7mS+Ek=";
  };

  nativeBuildInputs = [makeWrapper];
  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall
    install -Dm644 cafe.js "$out/libexec/gitcafe/cafe.js"
    makeWrapper ${lib.getExe bun} "$out/bin/cafe" \
      --add-flags "--config=/dev/null $out/libexec/gitcafe/cafe.js" \
      --prefix PATH : ${lib.makeBinPath [git]} \
      --set CAFE_NO_UPDATE_CHECK 1
    runHook postInstall
  '';

  meta = {
    description = "Command-line interface for GitCafe";
    homepage = "https://git.cafe";
    license = lib.licenses.unfree;
    inherit (bun.meta) platforms;
    mainProgram = "cafe";
  };
})
