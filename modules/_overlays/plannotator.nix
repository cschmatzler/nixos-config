{...}: final: prev: let
  version = "0.22.0";
  prebuilt = {
    x86_64-linux = {
      asset = "plannotator-linux-x64";
      hash = "sha256-03G3gkKjHWh7rc0ncrc1fjOVZ8h0tE56UDFtHRHSp9E=";
    };
    aarch64-linux = {
      asset = "plannotator-linux-arm64";
      hash = "sha256-tTtIbLDTtGs0UdKpyWQ/GiGb9I3nt/KXJGhxhM3oyiQ=";
    };
    x86_64-darwin = {
      asset = "plannotator-darwin-x64";
      hash = "sha256-ADMXxRWhxE0oSpQApe/KBZUiGZnym/LeZxJDl2orOQo=";
    };
    aarch64-darwin = {
      asset = "plannotator-darwin-arm64";
      hash = "sha256-e6utZ5avj36jGYvZYzqm8szmq5fF7GjC/eDnTkwqBlI=";
    };
  };
  platform =
    prebuilt.${prev.stdenv.hostPlatform.system}
    or (throw "Unsupported system for plannotator: ${prev.stdenv.hostPlatform.system}");
in {
  plannotator = prev.stdenvNoCC.mkDerivation {
    pname = "plannotator";
    inherit version;

    src = prev.fetchurl {
      url = "https://github.com/backnotprop/plannotator/releases/download/v${version}/${platform.asset}";
      inherit (platform) hash;
    };

    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;
    dontStrip = true;

    nativeBuildInputs = prev.lib.optionals prev.stdenv.hostPlatform.isLinux [
      prev.autoPatchelfHook
    ];
    buildInputs = prev.lib.optionals prev.stdenv.hostPlatform.isLinux [
      prev.stdenv.cc.cc
    ];

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/bin"
      cp "$src" "$out/bin/plannotator"
      chmod 0755 "$out/bin/plannotator"
      runHook postInstall
    '';

    meta = with prev.lib; {
      description = "Local browser-based review surface for AI coding agents";
      homepage = "https://github.com/backnotprop/plannotator";
      license = with licenses; [mit asl20];
      mainProgram = "plannotator";
      platforms = builtins.attrNames prebuilt;
      sourceProvenance = [sourceTypes.binaryNativeCode];
    };
  };
}
