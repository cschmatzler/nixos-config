{pkgs, ...}: {
  home = {
    packages = pkgs.callPackage ../packages.nix {};
  };
}
