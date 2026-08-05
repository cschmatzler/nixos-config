_: {
  den.aspects.database-cli.homeManager = {pkgs, ...}: {
    home.packages = with pkgs; [
      postgresql_17
      sqlite
    ];
  };
}
