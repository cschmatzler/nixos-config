{
  pkgs,
  ...
}: {
  imports = [
    ./zellij.nix
  ];

  home = {
    packages = pkgs.callPackage ../packages.nix {};
  };
}
