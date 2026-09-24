{den, ...}: {
  den.aspects.entire = {
    includes = [den.aspects.git];

    homeManager = {pkgs, ...}: let
      version = "0.11.2";
      release = builtins.getAttr pkgs.stdenv.hostPlatform.system {
        x86_64-linux = {
          asset = "entire_linux_amd64.tar.gz";
          hash = "sha256-y7kyjX5B5zzxqtkpWT+jB31W4xwJ8nweaeW9HiZyaUw=";
        };
        aarch64-linux = {
          asset = "entire_linux_arm64.tar.gz";
          hash = "sha256-UxHm2faJdoX7VP3hvPV8OIP9dRPDdOkIT7He30L1Yas=";
        };
        x86_64-darwin = {
          asset = "entire_darwin_amd64.tar.gz";
          hash = "sha256-qLH4ni5qLTz6TIGY1KiiAdCV/XFObLm18Z65y6cwa6M=";
        };
        aarch64-darwin = {
          asset = "entire_darwin_arm64.tar.gz";
          hash = "sha256-3b4BxFSGtJFN6kW2N9yXH1KySUasU+zJxQToiNSz8+M=";
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
      };
    };
  };
}
