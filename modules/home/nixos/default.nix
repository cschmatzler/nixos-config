{
  pkgs,
  ...
}: {
  imports = [
    ./zellij.nix
  ];

  home = {
    packages = pkgs.callPackage ../../nixos/packages.nix {};
  };
}
