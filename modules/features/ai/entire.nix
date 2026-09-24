{den, ...}: {
  den.aspects.entire = {
    includes = [den.aspects.git];

    homeManager = {pkgs, ...}: let
      version = "0.11.2";
      release = builtins.getAttr pkgs.stdenv.hostPlatform.system {
        x86_64-linux = {
          asset = "entire_linux_amd64.tar.gz";
          hash = "sha256-a7k7JX9TIeoxHwzY4Mp0tOqfj1vfOxHmje1XJC+CTSY=";
        };
        aarch64-linux = {
          asset = "entire_linux_arm64.tar.gz";
          hash = "sha256-UxHm/aaFaJe3S07Rf32plADs3tcoQL6oMG9MQZO1Yb0=";
        };
        x86_64-darwin = {
          asset = "entire_darwin_amd64.tar.gz";
          hash = "sha256-qLH4ni7aeYfYm6s9mdj1wQV8xOhtqApMUnjAFg0L2tM=";
        };
        aarch64-darwin = {
          asset = "entire_darwin_arm64.tar.gz";
          hash = "sha256-3b4BxFjCJJRInb0EInWUuOQ2BwXFPFHXyiRty8T0nJ4=";
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
