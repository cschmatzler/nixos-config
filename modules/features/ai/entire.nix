{den, ...}: {
  den.aspects.entire = {
    includes = [den.aspects.git];

    homeManager = {pkgs, ...}: let
      version = "0.10.0";
      release = builtins.getAttr pkgs.stdenv.hostPlatform.system {
        x86_64-linux = {
          asset = "entire_linux_amd64.tar.gz";
          hash = "sha256-zsywVrj3mR2Y1fmBm/VmXDmjTah+aOVnehVGAsAlTsw=";
        };
        aarch64-linux = {
          asset = "entire_linux_arm64.tar.gz";
          hash = "sha256-9kgVW9U180Aawq9CvGBQaSWEh+duNcBcGy7SiEqzrqc=";
        };
        x86_64-darwin = {
          asset = "entire_darwin_amd64.tar.gz";
          hash = "sha256-7orj2C4BaBaxoTCFN7Ah7P7i0n2BEy02Mbngp6edyos=";
        };
        aarch64-darwin = {
          asset = "entire_darwin_arm64.tar.gz";
          hash = "sha256-dl6WGbv/iMsC4DrgdOjcinWicMaUcpcOqd/CUUcX8p4=";
        };
      };
      entire = pkgs.stdenvNoCC.mkDerivation {
        pname = "entire";
        inherit version;

        src = pkgs.fetchurl {
          url = "https://github.com/entireio/cli/releases/download/v${version}/${release.asset}";
          inherit (release) hash;
        };

        sourceRoot = ".";
        installPhase = ''
          runHook preInstall

          install -Dm755 entire git-remote-entire -t $out/bin

          runHook postInstall
        '';

        meta = pkgs.entire.meta;
      };
    in {
      home = {
        packages = [entire];
        sessionVariables.ENTIRE_NO_AUTO_UPDATE = "1";

        file.".pi/agent/extensions/entire" = {
          source = ./_entire/extension;
          recursive = true;
        };
      };
    };
  };
}
