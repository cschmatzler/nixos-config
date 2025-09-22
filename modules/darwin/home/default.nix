{
  pkgs,
  lib,
  ...
}: let
  setWallpaperScript = import ../bin/wallpaper.nix {inherit pkgs;};
in {
  imports = [
    ./ghostty.nix
  ];

  home = {
    packages = pkgs.callPackage ../packages.nix {};
    activation = {
      "setWallpaper" = lib.hm.dag.entryAfter ["revealHomeLibraryDirectory"] ''
        echo "[+] Setting wallpaper"
        ${setWallpaperScript}/bin/set-wallpaper-script
      '';
    };
  };
}
