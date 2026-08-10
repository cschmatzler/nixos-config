{
  lib,
  pkgs,
}: let
  version = "0.38.0";
  runtimeLibraries = lib.makeLibraryPath [
    pkgs.lz4
    pkgs.stdenv.cc.cc
    pkgs.xxhash
    pkgs.zlib
    pkgs.zstd
  ];
  runtimePath = lib.makeBinPath [
    pkgs.coreutils
    pkgs.e2fsprogs
    pkgs.iproute2
    pkgs.openssh
    pkgs.util-linux
  ];
in
  pkgs.stdenvNoCC.mkDerivation {
    pname = "docker-sbx";
    inherit version;

    src = pkgs.fetchurl {
      url = "https://github.com/docker/sbx-releases/releases/download/v${version}/DockerSandboxes-linux-amd64.tar.gz";
      hash = "sha256-nrzqgx1NJw4lrhd3vxXiR1ar+/h5GtJylHVGgoOO0As=";
    };

    sourceRoot = "docker-sbx";
    nativeBuildInputs = [pkgs.makeWrapper];
    dontBuild = true;
    dontPatchELF = true;
    dontStrip = true;

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/bin" "$out/libexec/lib"
      install -m 0755 sbx "$out/bin/sbx-unwrapped"
      install -m 0755 containerd-shim-nerdbox-v1 "$out/libexec/"
      install -m 0755 containerd-shim-nerdbox-gpu-v1 "$out/libexec/"
      install -m 0755 mkfs.erofs "$out/libexec/"
      install -m 0755 libsailor.so "$out/libexec/lib/"
      install -m 0644 nerdbox-kernel-x86_64 "$out/libexec/"
      install -m 0644 nerdbox-rootfs-x86_64.erofs "$out/libexec/"
      install -m 0644 apparmor-profile "$out/libexec/"
      install -m 0644 LICENSE THIRD-PARTY-NOTICES "$out/"

      makeWrapper "$out/bin/sbx-unwrapped" "$out/bin/sbx" \
        --set NIX_LD "${pkgs.stdenv.cc.bintools.dynamicLinker}" \
        --set NIX_LD_LIBRARY_PATH "${runtimeLibraries}" \
        --set LD_LIBRARY_PATH "${runtimeLibraries}" \
        --prefix PATH : "${runtimePath}"

      runHook postInstall
    '';

    meta = {
      description = "Docker Sandboxes microVM CLI";
      homepage = "https://docs.docker.com/ai/sandboxes/";
      license = lib.licenses.unfree;
      mainProgram = "sbx";
      platforms = ["x86_64-linux"];
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  }
