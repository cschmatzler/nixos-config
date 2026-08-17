{den, ...}: {
  den.aspects.entire = {
    includes = [den.aspects.git];

    homeManager = {pkgs, ...}: {
      home = {
        packages = [pkgs.entire];
        sessionVariables.ENTIRE_NO_AUTO_UPDATE = "1";
      };
    };
  };
}
