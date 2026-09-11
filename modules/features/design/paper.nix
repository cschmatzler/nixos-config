{den, ...}: {
  den.aspects.paper.darwin = {pkgs, ...}: {
    environment.systemPackages = [pkgs.brewCasks.paper-design];
  };
}
