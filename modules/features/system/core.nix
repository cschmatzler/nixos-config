_: {
  den.aspects.core.os = {
    pkgs,
    lib,
    ...
  }: {
    # System utilities
    environment.systemPackages = lib.optionals pkgs.stdenv.hostPlatform.isLinux [
      pkgs.lm_sensors
    ];

    programs.fish.enable = true;
    environment.shells = [
      pkgs.fish
    ];

    nixpkgs = {
      config = {
        allowUnfree = true;
      };
    };

    nix = {
      package = pkgs.nix;
      settings = {
        cores = 0;
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        extra-substituters = [
          "https://nix-community.cachix.org"
          "https://devenv.cachix.org"
        ];
        extra-trusted-public-keys = [
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
        ];
      };
      gc = {
        automatic = true;
        options = "--delete-older-than 30d";
      };
      optimise.automatic = true;
    };
  };
}
