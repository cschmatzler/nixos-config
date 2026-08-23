{den, ...}: {
  den.aspects.janet = {
    includes = [
      den.aspects.host-darwin-base
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
      inputs',
      lib,
      pkgs,
      ...
    }: {
      system.stateVersion = 6;
      networking.hostName = "janet";
      networking.computerName = "janet";
      documentation.doc.enable = false;

      environment.systemPackages = with pkgs; [
        notion-app
        brewCasks.notion-calendar
        inputs'.llm-agents.packages.t3code-desktop
      ];

      system.defaults.dock.persistent-apps = lib.mkAfter [
        "/Applications/Nix Apps/T3 Code (Alpha).app"
      ];
    };
  };
}
