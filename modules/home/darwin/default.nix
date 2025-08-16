{
  pkgs,
  config,
  lib,
  constants,
  ...
}: let
  setWallpaperScript = import ../../darwin/lib/wallpaper.nix {inherit pkgs;};
in {
  imports = [
    ./ghostty.nix
  ];

  home = {
    packages = pkgs.callPackage ../../darwin/packages.nix {};
    activation = {
      "setWallpaper" = lib.hm.dag.entryAfter ["revealHomeLibraryDirectory"] ''
        echo "[+] Setting wallpaper"
        ${setWallpaperScript}/bin/set-wallpaper-script
      '';
    };
  };
}
