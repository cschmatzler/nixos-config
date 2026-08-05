_: {
  den.aspects.containers-cli.homeManager = {pkgs, ...}: {
    home.packages = with pkgs; [
      docker
      docker-compose
      lazydocker
    ];
  };
}
