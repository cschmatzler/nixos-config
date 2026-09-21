{den, ...}: {
  den.aspects.entire = {
    includes = [den.aspects.git];

    homeManager = {pkgs, ...}: let
      version = "0.10.6";
      release = builtins.getAttr pkgs.stdenv.hostPlatform.system {
        x86_64-linux = {
          asset = "entire_linux_amd64.tar.gz";
          hash = "sha256-rdVlkbsdQpwAg4ow7NRKSYNKyISFQAXgUWTS6SkMZgI=";
        };
        aarch64-linux = {
          asset = "entire_linux_arm64.tar.gz";
          hash = "sha256-w40hCrE5vf9D6tYOB+RXtjBcuPUfUECzyWdrleDl8yo=";
        };
        x86_64-darwin = {
          asset = "entire_darwin_amd64.tar.gz";
          hash = "sha256-b078a3v8E7Q2V40eosF6PBTTy1/MZBZTINvYyHD06PE=";
        };
        aarch64-darwin = {
          asset = "entire_darwin_arm64.tar.gz";
          hash = "sha256-vM7X0ZEeS43tmTPD7bLzX1D3a6hFct/xrIVOM3R6cHA=";
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
