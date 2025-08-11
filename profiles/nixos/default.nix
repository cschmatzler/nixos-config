{
  pkgs,
  nixvim,
  user,
  ...
}: {
  imports = [];

  users.users.${user} = {
    isNormalUser = true;
    home = "/home/${user}";
    extraGroups = [
      "wheel"
      "sudo"
      "network"
      "systemd-journal"
    ];
    shell = pkgs.fish;
  };

  home-manager = {
    useGlobalPkgs = true;
    users.${user} = {
      pkgs,
      config,
      lib,
      ...
    }: {
      _module.args = {inherit user;};
      imports = [
        nixvim.homeModules.nixvim
        ../base/home-manager
      ];
      home = {
        stateVersion = "25.05";
      };
    };
  };
}
