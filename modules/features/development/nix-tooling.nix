_: {
  den.aspects.nix-tooling.homeManager = {pkgs, ...}: {
    home.packages = with pkgs; [
      alejandra
      deadnix
      nil
      nurl
      statix
    ];
  };
}
