{den, ...}: {
  den.aspects.janet = {
    includes = [
      den.aspects.host-darwin-base
      den.aspects.pi
      den.aspects.syncthing
    ];

    provides.to-users = {
      includes = [
        den.aspects.user-workstation
        den.aspects.user-personal
        den.aspects.mosh-client
      ];
      homeManager.home.stateVersion = "25.11";
    };

    darwin = {
      system.stateVersion = 6;
      networking.hostName = "janet";
      networking.computerName = "janet";
      documentation.doc.enable = false;
    };
  };
}
