{
  den,
  lib,
  ...
}: {
  options.flake.darwinConfigurations = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.raw;
    default = {};
  };

  config.den = {
    default = {
      nixos = {
        home-manager.useGlobalPkgs = true;
      };
      darwin = {
        home-manager.useGlobalPkgs = true;
      };
      homeManager = {
        home.enableNixpkgsReleaseCheck = false;
        programs.home-manager.enable = true;
      };
      includes = [
        den.provides.define-user
        den.provides.inputs'
      ];
    };

    schema.user.classes = lib.mkDefault ["homeManager"];
  };
}
