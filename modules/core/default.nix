{pkgs, ...}: {
  programs.fish.enable = true;

  nixpkgs = {
    config = {
      allowUnfree = true;
    };
    overlays = let
      path = ../../overlays;
    in
      with builtins;
        map (n: import (path + ("/" + n))) (
          filter (n: match ".*\\.nix" n != null || pathExists (path + ("/" + n + "/default.nix"))) (
            attrNames (readDir path)
          )
        );
  };

  nix = {
    package = pkgs.nix;
    settings = {
      trusted-users = [
        "@admin"
      ];
      substituters = [
        "https://nix-community.cachix.org"
        "https://cache.nixos.org"
      ];
      trusted-public-keys = ["cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="];
    };
    gc = {
      automatic = true;
      options = "--delete-older-than 30d";
    };
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };
}
