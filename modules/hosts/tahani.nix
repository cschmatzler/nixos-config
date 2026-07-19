{den, ...}: let
  local = import ../_lib/local.nix;
in {
  den.aspects.tahani = {
    includes = [
      den.aspects.host-nixos-base
      den.aspects.mosh-server
      den.aspects.opencode
      den.aspects.email
      den.aspects.ynab
      den.aspects.syncthing
    ];

    provides.to-users = {
      includes = [
        den.aspects.user-workstation
        den.aspects.user-personal
        den.aspects.email
        den.aspects.ynab
      ];
      homeManager.home.stateVersion = "25.11";
    };

    nixos = {pkgs, ...}: {
      system.stateVersion = "25.11";
      networking.hostName = "tahani";

      environment.systemPackages = [pkgs._1password-cli];
      programs.nix-ld.enable = true;

      imports = [
        ./_parts/tahani/hardware.nix
        ./_parts/tahani/networking.nix
      ];

      virtualisation.docker.enable = true;
      users.users.${local.user.name}.extraGroups = [
        "docker"
      ];
    };
  };
}
