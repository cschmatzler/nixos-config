{den, ...}: {
  den.aspects.user-darwin-laptop = {
    includes = [
      den.aspects.user-workstation
    ];

    homeManager = {
      fonts.fontconfig.enable = true;
    };
  };
}
