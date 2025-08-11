{
  agenix,
  config,
  lib,
  pkgs,
  user,
  ...
}: {
  imports = [
    agenix.darwinModules.default
  ];

  nixpkgs = {
    config = {
      allowUnfree = true;
      allowBroken = false;
      allowInsecure = false;
      allowUnsupportedSystem = false;
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
        "${user}"
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

  environment.systemPackages = with pkgs; [
    agenix.packages."${pkgs.system}".default
  ];

  system = {
    primaryUser = user;
    stateVersion = 5;
  };

  programs.fish.enable = true;

  services.tailscale = {
    enable = true;
  };
}
