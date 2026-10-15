_: {
  den.aspects.taste.darwin = {
    lib,
    pkgs,
    ...
  }: let
    version = "0.3.3";
    taste = import ../../_lib/darwin-app.nix {
      inherit pkgs version;
      pname = "taste";
      appName = "Taste";
      src = pkgs.fetchurl {
        name = "Taste-${version}.zip";
        url = "https://buildwithtaste.com/downloads/Taste-${version}.zip";
        hash = "sha256-bW0bZLvH9vhJ7qH01bembBiYhxPY8PYtiKvuIsTOPWg=";
      };
      meta = {
        description = "Build a reusable design taste profile for AI coding tools";
        homepage = "https://buildwithtaste.com";
        changelog = "https://buildwithtaste.com/appcast.xml";
        license = lib.licenses.unfree;
      };
    };
  in {
    environment.systemPackages = [taste];
  };
}
