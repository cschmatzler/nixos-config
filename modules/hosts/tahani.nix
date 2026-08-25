{den, ...}: {
  den.aspects.tahani = {
    includes = [
      den.aspects.host-nixos-base
      den.aspects.home-assistant
      den.aspects.mosh-server
      den.aspects.email
      den.aspects.syncthing
      den.aspects.plannotator
    ];

    provides.to-users = {
      includes = [
        den.aspects.user-workstation
        den.aspects.user-personal
        den.aspects.email
      ];
      homeManager.home.stateVersion = "25.11";
    };

    nixos = {pkgs, ...}: {
      system.stateVersion = "25.11";
      networking.hostName = "tahani";

      environment.systemPackages = [pkgs._1password-cli];
      programs.nix-ld.enable = true;

      imports = [
        ./_parts/tahani/executor.nix
        ./_parts/tahani/hardware.nix
        ./_parts/tahani/networking.nix
        ./_parts/tahani/t3-code.nix
      ];

      virtualisation.docker.enable = true;
      users.users.${(import ../_lib/local.nix).user.name}.extraGroups = [
        "docker"
      ];
    };
  };
}
