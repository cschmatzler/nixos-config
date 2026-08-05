_: {
  den.aspects = {
    mosh-server.nixos.programs.mosh = {
      enable = true;
      openFirewall = true;
    };

    mosh-client.homeManager = {pkgs, ...}: {
      home.packages = [pkgs.mosh];
    };
  };
}
