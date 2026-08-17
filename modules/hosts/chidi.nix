{den, ...}: {
  den.aspects.chidi = {
    includes = [
      den.aspects.host-darwin-base
    ];

    provides.to-users = {
      includes = [
        den.aspects.user-workstation
        den.aspects.user-work
        den.aspects.mosh-client
      ];
      homeManager.home.stateVersion = "25.11";
    };

    darwin = {pkgs, ...}: {
      system.stateVersion = 6;
      networking.hostName = "chidi";
      networking.computerName = "chidi";
      documentation.doc.enable = false;

      environment.systemPackages = with pkgs; [
        brewCasks.granola
        linear
        notion-app
        brewCasks.notion-calendar
        slack
      ];
    };
  };
}
